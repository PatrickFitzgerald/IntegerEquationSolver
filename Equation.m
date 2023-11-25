classdef Equation < handle
	
	properties (GetAccess = public, SetAccess = private)
		LHS Expression;
		RHS SetOfIntegers;
		label = '';
	end
	
	methods
		% LHS can be Variable or Expression
		% RHS can either be scalar integer, or SetOfIntegers
		function eq_ = Equation(LHS,RHS,label)
			
			% If the label was provided, assign it
			if exist('label','var')
				eq_.label = label;
			end
			
			if isa(LHS,'Variable')
				temp = LHS;
				LHS = Expression();
				LHS.varList_P = temp;
			end
			assert( isa(LHS,'Expression'), 'The input must be an Expression or be convertible to an Expression');
			
			if ~isa(RHS,'SetOfIntegers')
				assert( isnumeric(RHS) && isscalar(RHS) && mod(RHS,1)==0, 'The RHS must be an integer');
				RHS = SetOfIntegers.makeConstant(RHS);
			end
			
			eq_.LHS = LHS;
			eq_.RHS = RHS;
			
			% Register this equation
			Equation.addEquation(eq_);
			
			% Determine if any of the LHS's aux equations need their name
			% updated
			needsFixing = strcmp( {eq_.LHS.auxEqs.label}, '?' );
 			for k = 1:numel(needsFixing)
				if needsFixing(k)
					eq_.LHS.auxEqs(k).label = sprintf('%s%s', eq_.label, getExcelColumnLabel(k));
					fprintf('<RNM> %s\n',eq_.LHS.auxEqs(k).toString);
				end
			end
			
			% Try to simplify the equation. Only perform this if we're not
			% working with an auxiliary equation already
			if eq_.LHS.canBeSplitAndSimplified()
				% This will simplify the equation by fracturing it into
				% separate equations. This allows us to place more specific
				% constraints on these 
				[LHS_,changed] = eq_.LHS.simplifyTermwise(eq_.label);
				% If anything happened, apply it and announce it.
				if changed
					eq_.LHS = LHS_;
					fprintf('<SUB> %s\n',eq_.toString());
				end
			end
			
		end
		
		function str = toString(eq_)
			labelLength = Equation.getMaxLabelLength();
			assert(isscalar(eq_),'Only one eq can be stringified at a time')
			if cardinality( eq_.RHS ) == 1
				rhsString = sprintf('%d',eq_.RHS.ranges(1,1));
			else
				rhsString = sprintf('Any of %s', eq_.RHS.toString() );
			end
			str = sprintf('[\b%s]\b%s %s = %s', eq_.label, repmat(' ',1,labelLength-numel(eq_.label)), eq_.LHS.toString, rhsString );
		end
		function disp(eqs)
			for k = 1:numel(eqs)
				fprintf('%s\n',eqs(k).toString());
			end
		end
		
		function changed = refine(eq_)
			
% TODO: there will be equations (primarily auxiliary equations) that have
% RHS values with more options than what the LHS will ever use (i.e. the
% equation is not constraining). These should be removed.
% This will also be a good spot to detect if an equation is impossible,
% i.e. cardinality on RHS = 0
			
			% Remove solved terms
			changed = rearrangeConstants(eq_);
			
			% Get a list of values
			numTerms = eq_.LHS.numTerms;
			allTerms = 1:numTerms;
			valueSets = eq_.LHS.getPossibleValues( allTerms );
			
			for omitInd = numTerms : -1 : 1 % the more complex ones (later) will be more fruitful
				RHS_ = eq_.RHS;
				% We'll move EVERYTHING but the selected term to the other
				% side and see what we can learn
				for termInd = 1:numTerms
					if termInd == omitInd
						continue
					end
					RHS_ = RHS_ - valueSets(termInd);
				end
				
				proposedValues = intersect( valueSets(omitInd), RHS_ );
				% Apply this constraint (even if it doesn't look like
				% anything useful now, it still may be, so just do them
				% all).
				changed = changed | eq_.LHS.applyConstraint(omitInd,proposedValues); % NOT using ||, since that would prevent applyConstraint() from running.
				
			end
			
		end
		function changed = rearrangeConstants(eq_)
			
			% Get a copy of the values for all the completely solved terms
			numTerms = eq_.LHS.numTerms;
			allTerms = 1:numTerms;
			isSolvedVec = eq_.LHS.getTermIsSolved( allTerms );
			% Extract their values
			valueSets = eq_.LHS.getPossibleValues( isSolvedVec );
			% Remove those terms, since we'll be accounting for them
			% ourselves
			eq_.LHS = eq_.LHS.deleteTerms( isSolvedVec );
			% Absorb everything into the RHS. All the returned terms are
			% summed on the LHS, so we need to subtract them over.
			for k = 1:numel(valueSets)
				eq_.RHS = eq_.RHS - valueSets(k);
			end
			
			changed = false;
			if any(isSolvedVec)
				fprintf('<UPD> %s\n',eq_.toString())
				changed = true;
			end
			
		end
	end
	
	methods (Static) % global functions
		function clearList()
			Equation.eqListInterface('clear');
		end
		function addEquation(eq_)
			Equation.eqListInterface('add',eq_);
		end
		function eqList = getEqList()
			eqList = Equation.eqListInterface('getFull');
		end
		function num = getNumAuxiliary()
			num = Equation.eqListInterface('getNumAuxiliary');
		end
		function length_ = getMaxLabelLength()
			length_ = Equation.eqListInterface('getMaxLabelLength');
		end
	end
	methods (Static, Access = private)
		function varargout = eqListInterface(mode,varargin)
			
			persistent eqList numProper numAuxiliary maxLabelLength;
			if ~isa(eqList,'Equation') || isempty(numProper) || isempty(numAuxiliary) || isempty(maxLabelLength) || isnumeric(eqList) || strcmp(mode,'clear')
				eqList = Equation.empty(0,1);
				numProper = 0;
				numAuxiliary = 0;
				maxLabelLength = 0;
				fprintf('Equation list has been set to an empty state\n')
				% If we were asked to clear, then we can terminate
				if strcmp(mode,'clear')
					return
				end
			end
			
% Reminder: if removing an equation, don't decrement the
% numProper/numAuxiliary. These should still be useful for assigning new
% labels.
			
			switch mode
				case 'add'
					eq_ = varargin{1};
					eqList(end+1,1) = eq_;
					
					% If there isn't a label yet, assign one
					if isempty(eq_.label)
						eq_.label = sprintf('Eq %u',numProper+1);
						numProper = numProper + 1;
					else
						numAuxiliary = numAuxiliary + 1;
					end
					
					maxLabelLength = max( maxLabelLength, numel(eq_.label) );
					
					fprintf('<NEW> %s\n',eq_.toString())
					return
				case 'getFull'
					varargout = {eqList};
					return
				case 'getNumAuxiliary'
					varargout = {numAuxiliary};
					return
				case 'getMaxLabelLength'
					varargout = {maxLabelLength};
					return
				otherwise
					error('Unknown mode');
			end
			
		end
	end
	
end