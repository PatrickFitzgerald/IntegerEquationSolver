classdef Equation % not handle
	
	properties (GetAccess = public, SetAccess = private)
		LHS Expression;
		RHS SetOfIntegers;
		label = '';
	end
	properties (Access = private)
		isAuxiliary (1,1) logical = true; % This indicates whether the user directly created this equation or not
	end
	
	
	% * * * * * * * * * * * * * * * CONSTRUCTOR * * * * * * * * * * * * * *
	methods (Access = public)
		% LHS can be Variable or Expression
		% RHS can either be scalar integer, or SetOfIntegers
		function eq_ = Equation(LHS,RHS,isAuxiliary)
			
			% Cast the inputs, if necessary
			if isa(LHS,'Variable')
				LHS = Expression.fromVariable(LHS);
			end
			if ~isa(RHS,'SetOfIntegers')
				RHS = SetOfIntegers.makeConstant(RHS);
			end
			% Store the LHS,RHS. Matlab will do some additional type/size
			% checks.
			eq_.LHS = LHS;
			eq_.RHS = RHS;
			
			eq_.isAuxiliary = isAuxiliary;
			
			% Try to simplify the equation. Only perform this if we're not
			% working with an auxiliary equation already
			if eq_.LHS.canBeSplitAndSimplified()
				% This will simplify the equation by fracturing it into
				% separate equations. This allows us to place more specific
				% constraints on these 
				[LHS_,changed] = eq_.LHS.simplifyTermwise();
				% If anything happened, apply it and announce it.
				if changed
					eq_.LHS = LHS_;
				end
			end
			
		end
	end
	% * * * * * * * * * * * * * * * CONSTRUCTOR * * * * * * * * * * * * * *
	
	
	% * * * * * * * * * OVERLOADED OPERATORS/FUNCTIONS * * * * * * * * * *
	methods (Access = public)
		function disp(eqs)
			
			% Report size
			sizeStr = createSizeStr(size(eqs));
			fprintf( '  %s Equation\n', sizeStr );
			
			% Report each item, indenting them each, so they are
			% distinct from the size preface
			for k = 1:numel(eqs)
				rawStr = eqs(k).toString();
				fprintf( '%s\n', indent(rawStr, '    ' ) );
			end
			% And an extra newline for good measure.
			fprintf('\n');
			
		end
	end
	% * * * * * * * * * OVERLOADED OPERATORS/FUNCTIONS * * * * * * * * * *
	
	
	% * * * * * * * * * * * * HELPER FUNCTIONS * * * * * * * * * * * * * *
	methods (Access = public)
		function str = toString(eq_)
			
			assert(isscalar(eq_),'Only one equation can be stringified at a time')
			
			% Generate the stringification of the LHS expression, which may
			% contain some number of sub-equations (which them may contain
			% sub-equations, etc)
			[strLHS,subEqStr] = eq_.LHS.toString();
			
			% We'll indent the sub equations
			subEqStr = indent( subEqStr, '  ' );
			% And we'll insert a newline at the front (if it's not empty)
			if ~isempty(subEqStr)
				subEqStr = sprintf('\n%s',subEqStr);
			end
			
			% Prepare the representation of the RHS
			if cardinality( eq_.RHS ) == 1
				strRHS = sprintf('%d',eq_.RHS.ranges(1,1));
			else
				strRHS = sprintf('Any of %s', eq_.RHS.toString() );
			end
			
			% Bring it all together
			str = sprintf('[\b%s]\b %s = %s%s', eq_.label, strLHS, strRHS, subEqStr );
			
		end
	end
	% * * * * * * * * * * * * HELPER FUNCTIONS * * * * * * * * * * * * * *
	
	
	% * * * * * * * * * * * EQUATION MANIPULATION  * * * * * * * * * * * * 
	methods (Access = public)
		function [eq_,changed] = refine(eq_)
			
% if we make equations with more flexibility on the RHS than the LHS needs,
% we should mark that equation as 0=0, since it will confer no increased
% info
			
			% Remove solved terms
			[eq_,changed] = rearrangeConstants(eq_);
			
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
			
			% Recursively refine sub-equations
			for k = 1:numel(eq_.LHS.auxEqs)
				eq_.LHS.auxEqs(k) = eq_.LHS.auxEqs(k).refine();
			end
			
		end
	end
	methods (Access = private)
		function [eq_,changed] = rearrangeConstants(eq_)
			
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
				if GlobalParams.printEquationUpdates
					fprintf('<UPD> %s\n',hangingIndent(eq_.toString(),'      '))
				end
				changed = true;
			end
			
		end
	end
	% * * * * * * * * * * * EQUATION MANIPULATION  * * * * * * * * * * * * 
	
	
	% * * * * * * * * * * * * * EQUATION LABELING * * * * * * * * * * * * *
	methods (Access = public)
		% This ingests a vector of equation objects and assigns them
		% ordered labels like "Eq 03" (by omitting the `preface` argument).
		% This also re-labels any contained auxiliary equations
		% recursively.
		function eqs = assignOrderedLabels(eqs)
			
			% Require this gets called only on non-auxiliary equations
			assert( ~any([eqs.isAuxiliary]), 'This function can only be called on non-auxiliary equations, i.e. user created.' );
			
			% Call the internal function
			eqs = assignOrderedLabelsInternal(eqs,'Eq ');
			
		end
	end
	methods (Access = private)
		% This ingests a vector of equation objects and assigns them
		% ordered labels like "Eq 03" (by omitting the `preface` argument).
		% This also re-labels any contained auxiliary equations
		% recursively.
		function eqs = assignOrderedLabelsInternal(eqs,preface)
			
			% Plan how we'll pad with zeros
			maxQuant = numel(eqs);
			labelFormat = sprintf('%%s%%0%uu',getNumDigits(maxQuant));
			
			% Throw a warning if we're relabeling a non-empty label on a
			% non-auxiliary equation.
			isNonAuxAndNonEmpty = arrayfun( @(e) ~isempty(e.label) && ~e.isAuxiliary, eqs(:) );
			if any(isNonAuxAndNonEmpty)
				s = sum(isNonAuxAndNonEmpty);
				warning('Overwriting %u equation label%s',s,repmat('s',1,s~=1));
			end
			
			for k = 1:maxQuant
				newLabel = sprintf(labelFormat,preface,k);
				% Assign the label
				eqs(k).label = newLabel;
				% Recur if needed
				if numel(eqs(k).LHS.auxEqs) > 0
					subPreface = [newLabel,'.']; % separate numbers with a period
					eqs(k).LHS.auxEqs = assignOrderedLabelsInternal( eqs(k).LHS.auxEqs, subPreface );
				end
			end
			
		end
	end
	% * * * * * * * * * * * * * EQUATION LABELING * * * * * * * * * * * * *
	
end