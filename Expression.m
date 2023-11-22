classdef Expression
	
	% All variable lists are added (after their respective operations)
	properties
		varList_P        (1,:) Variable = Variable.empty(1,0);
		varList_M        (1,:) Variable = Variable.empty(1,0);
		varList_P_times  (2,:) Variable = Variable.empty(2,0); % +var * var
		varList_P_divide (2,:) Variable = Variable.empty(2,0); % +var / var
		varList_M_times  (2,:) Variable = Variable.empty(2,0); % -var * var
		varList_M_divide (2,:) Variable = Variable.empty(2,0); % -var / var
	end
	properties
		auxEqs (:,1) Equation = Equation.empty(0,1);
	end
	
	% The overloaded operators depend on the matlab parsing engine to still
	% execute them following the standard order of operations. Thus, an
	% expression will never be divided or multiplied directly
	methods
		function exprC = plus(exprA,B)
			% If this function was invoked, then A is an expression
			if isa(B,'Expression')
				% Just combine expressions, since everything is added
				exprC = Expression();
				exprC.varList_P        = [ exprA.varList_P,        B.varList_P ];
				exprC.varList_M        = [ exprA.varList_M,        B.varList_M ];
				exprC.varList_P_times  = [ exprA.varList_P_times,  B.varList_P_times  ];
				exprC.varList_P_divide = [ exprA.varList_P_divide, B.varList_P_divide ];
				exprC.varList_M_times  = [ exprA.varList_M_times,  B.varList_M_times  ];
				exprC.varList_M_divide = [ exprA.varList_M_divide, B.varList_M_divide ];
				% Ensure we retain the auxiliary equations from both inputs
				exprC.auxEqs = [exprA.auxEqs;B.auxEqs];
			elseif isa(B,'Variable')
				exprC = exprA; % build off exprA
				exprC.varList_P = [ exprC.varList_P, B ]; % add to the plus() list
			else
				error('Unexpected operation with unknown type')
			end
		end
		function exprC = minus(exprA,B)
			% If this function was invoked, then A is an expression
			if isa(B,'Expression')
				% Defer to the uminus and plus implementations
				exprC = exprA + (-B);
			elseif isa(B,'Variable')
				exprC = exprA; % build off exprA
				exprC.varList_M = [ exprC.varList_M, B ]; % add to the minus() list
			else
				error('Unexpected operation with unknown type')
			end
		end
		function exprB = uminus(exprA)
			% Swap the signs
			exprB = Expression();
			exprB.varList_P        = exprA.varList_M;
			exprB.varList_M        = exprA.varList_P;
			exprB.varList_P_times  = exprA.varList_M_times;
			exprB.varList_P_divide = exprA.varList_M_divide;
			exprB.varList_M_times  = exprA.varList_P_times;
			exprB.varList_M_divide = exprA.varList_P_divide;
			% Ensure we retain carry the auxiliary equations
			exprB.auxEqs = exprA.auxEqs;
		end
		function exprC = times(exprA,B)
			assert( isa(B,'Variable'),'Expressions are only supported for multiplication with a single variable')
			varB = B; % relabel
			
			% We're going to handle the terms like so
			%   (a + b*c + d/e) * f = a*f + [b*c]*f + [d*f]/e
			% (note the signs can be flipped in the obvious way)
			% 
			% The square brackets [] represent quantities replaced with an
			% auxiliary variable, so that the expressions remain locally
			% simple and of the form that this framework supports.
			% This choice of *which* things we abstract off with aux
			% variables extends nicely to keeping the division operation as
			% the outer-most operation of the multiplication and division.
			% This leaves the integer-division constraints as conservative
			% as possible.
			
% TODO: There may be cases where we don't want to distribute an
% expression... e.g. when representing (3+7)/10 --> 3/10 is not valid, nor
% is 7/10, but if the parentheses are respected then the eq is valid...
			
			exprC = Expression();
			% Copy any existing auxiliary equations
			exprC.auxEqs = exprA.auxEqs;
			
			% Sweep through the contents of exprA
			[FIs,LIs] = exprA.lookup( 1:exprA.numTerms );
			for k = 1:numel(FIs)
				vars = exprA.(exprA.fields{FIs(k)})(:,LIs(k));
				
				% Prepare an auxiliary variable and equation if relevant
				if ismember( FIs(k), [3,4,5,6] )
					
					% The new equation will be of the form
					%    -auxVar + U*V = 0
					% where U,V are variables.
					U = vars(1); % For both mult and div cases, this is true
					switch FIs(k)
						case {3,5} % original term was multipliction
							V = vars(2);
						case {4,6} % original term was division
							V = varB;
					end
					
					% Construct the auxiliary variable
					naivePossibleValues = U.possibleValues * V.possibleValues;
					auxVar = Variable.auxVarCreationHelper(naivePossibleValues);
					% Prepare the auxiliar expression it will be used in
					auxExpr = Expression();
					auxExpr.varList_M(1) = auxVar;
					auxExpr.varList_P_times(:,1) = [U;V]; % new eq is always multiplication
					% Create the equation representing auxExpr = 0
					exprC = constructAndRecordAuxEq(exprC,auxExpr); % no parent label now, defer to later
					
				end
				switch FIs(k)
					case 1 % varList_P
						exprC = exprC + (vars(1)*varB);
					case 2 % varList_M
						exprC = exprC - (vars(1)*varB);
					case 3 % varList_P_times
						exprC = exprC + (auxVar*varB);
					case 4 % varList_P_divide
						exprC = exprC + (auxVar/vars(2));
					case 5 % varList_M_times
						exprC = exprC - (auxVar*varB);
					case 6 % varList_M_divide
						exprC = exprC - (auxVar/vars(2));
					otherwise
						error('Unsupported case');
				end
			end
			
		end
		function exprC = rdivide(exprA,B)
			
			% This code is almost identical to times(). I've stripped out
			% all the comments from that implementation. All ways that this
			% differs from that are called out with comments.
			
			assert( isa(B,'Variable'),'Expressions are only supported for multiplication with a single variable')
			varB = B;
			
			% The behavior relevant to division is
			%   (a + b*c + d/e) / f = a/f + [b*c]/f + d/[e*f]
			
			exprC = Expression();
			exprC.auxEqs = exprA.auxEqs;
			
			[FIs,LIs] = exprA.lookup( 1:exprA.numTerms );
			for k = 1:numel(FIs)
				vars = exprA.(exprA.fields{FIs(k)})(:,LIs(k));
				
				if ismember( FIs(k), [3,4,5,6] )
					
					% U definition moved into switch block
					switch FIs(k)
						case {3,5} % STILL multipliction
							U = vars(1); % new
							V = vars(2); % new
						case {4,6} % STILL division
							U = vars(2); % new
							V = varB;
					end
					
					naivePossibleValues = U.possibleValues * V.possibleValues;
					auxVar = Variable.auxVarCreationHelper(naivePossibleValues);
					
					auxExpr = Expression();
					auxExpr.varList_M(1) = auxVar;
					auxExpr.varList_P_times(:,1) = [U;V];
					
					exprC = constructAndRecordAuxEq(exprC,auxExpr);
					
				end
				switch FIs(k)
					case 1 % STILL varList_P
						exprC = exprC + (vars(1)/varB); % new
					case 2 % STILL varList_M
						exprC = exprC - (vars(1)/varB); % new
					case 3 % STILL varList_P_times
						exprC = exprC + (auxVar/varB); % new
					case 4 % STILL varList_P_divide
						exprC = exprC + (vars(1)/auxVar); % new
					case 5 % STILL varList_M_times
						exprC = exprC - (auxVar/varB); % new
					case 6 % STILL varList_M_divide
						exprC = exprC - (vars(1)/auxVar); % new
					otherwise
						error('Unsupported case');
				end
			end
		end
		function exprC = ldivide(~,~) %#ok<STOUT>
			error('Left division of an expression is not supported (it means you''re dividing by something complicated...)');
		end
		function exprC = mtimes(exprA,B)
			% Defer to the non-matrix operation
			exprC = times(exprA,B);
		end
		function exprC = mrdivide(exprA,B)
			% Defer to the non-matrix operation
			exprC = rdivide(exprA,B);
		end
		function exprC = mldivide(exprA,B)
			% Defer to the non-matrix operation
			exprC = ldivide(exprA,B);
		end
		function eqC = eq(exprA,B)
			% Try to form an equation
			eqC = Equation(exprA,B);
		end
		
		function disp(expr)
			fprintf('  Expression: %s\n', expr.toString());
		end
		
		function str = toString(expr)
			
			numTerms_ = expr.numTerms;
			
			if numTerms_ == 0
				str = '0';
			else % at least one term
				termIndices = 1:numTerms_;
				[fieldInds,LIs] = expr.lookup(termIndices);
				
				for k = termIndices
					
					isFirst = k==1;
					
					field_ = expr.fields{fieldInds(k)};
					LI = LIs(k);
					
					switch field_
						case 'varList_P'
							substr = expr.varList_P(LI).label;
							isNegative = false;
						case 'varList_M'
							substr = expr.varList_M(LI).label; % omit sign
							isNegative = true;
						case 'varList_P_times'
							substr = [...
								expr.varList_P_times(1,LI).label,...
								'*',...
								expr.varList_P_times(2,LI).label...
							];
							isNegative = false;
						case 'varList_P_divide'
							substr = [...
								expr.varList_P_divide(1,LI).label,...
								'/',...
								expr.varList_P_divide(2,LI).label...
							];
							isNegative = false;
						case 'varList_M_times'
							substr = [...
								expr.varList_M_times(1,LI).label,...
								'*',...
								expr.varList_M_times(2,LI).label...
							];
							isNegative = true;
						case 'varList_M_divide'
							substr = [...
								expr.varList_M_divide(1,LI).label,...
								'/',...
								expr.varList_M_divide(2,LI).label...
							];
							isNegative = true;
						otherwise
							error('unsupported field')
					end
					% substr will omit the sign
					
					if isFirst && isNegative
						str = ['-',substr];
					elseif isFirst % & positive
						str = substr;
					else % not first
						if isNegative
							sgn = ' - ';
						else
							sgn = ' + ';
						end
						str = [ str, sgn, substr ]; %#ok<AGROW>
					end
				end
				
			end
		end
	end
	
	
	properties (Constant)
		fields = {
			'varList_P';
			'varList_M';
			'varList_P_times';
			'varList_P_divide';
			'varList_M_times';
			'varList_M_divide';
		};
	end
	properties (GetAccess = public, SetAccess = private, Dependent)
		numTerms;
		numTermsByType; % see fields for ordering
	end
	methods % getter
		function numTermsByType_ = get.numTermsByType(expr)
			numTermsByType_ = nan(size(expr.fields));
			for fInd = 1:numel(expr.fields)
				numTermsByType_(fInd) = size(expr.(expr.fields{fInd}),2);
			end
		end
		function numTerms_ = get.numTerms(expr)
			numTerms_ = sum( expr.numTermsByType );
		end
	end
	methods
		% This helps indexing the terms in the expression. These won't
		% necessarily be ordered by their creation order, but will allow
		% more programmatic interaction with the various terms
		function [fieldInd,localInd] = lookup(expr,termIndex)
			termIndex = Expression.booleanCheck(termIndex);
			% Construct the maps
			sizes = expr.numTermsByType;
			fieldIndMapping = repelem( 1:numel(expr.fields), sizes.' );
			localIndLists = arrayfun( @(sz) {1:sz}, sizes(:).' );
			localIndMapping = cat(2, localIndLists{:} );
			
			% Evaluate the maps on the requested indices
			fieldInd = fieldIndMapping(termIndex);
			localInd = localIndMapping(termIndex);
		end
		function set = getPossibilities(expr,termIndex)
			termIndex = Expression.booleanCheck(termIndex);
			
			if ~isscalar(termIndex)
				% Recur to make this implementation a bit cleaner
				set = repmat( SetOfIntegers(), size(termIndex) );
				for k = 1:numel(termIndex)
					set(k) = expr.getPossibilities(termIndex(k));
				end
				return
			end
			% else continue and generate a scalar
			
			[fieldInd,LI] = expr.lookup(termIndex);
			field_ = expr.fields{fieldInd};
			switch field_
				case 'varList_P'
					set = expr.varList_P(LI).possibleValues;
				case 'varList_M'
					set = -expr.varList_M(LI).possibleValues;
				case 'varList_P_times'
					set = expr.varList_P_times(1,LI).possibleValues ...
						* expr.varList_P_times(2,LI).possibleValues;
				case 'varList_P_divide'
					set = expr.varList_P_divide(1,LI).possibleValues ...
						/ expr.varList_P_divide(2,LI).possibleValues;
				case 'varList_M_times'
					set = ...
						- expr.varList_M_times(1,LI).possibleValues ...
						* expr.varList_M_times(2,LI).possibleValues;
				case 'varList_M_divide'
					set = ...
						- expr.varList_M_divide(1,LI).possibleValues ...
						/ expr.varList_M_divide(2,LI).possibleValues;
				otherwise
					error('unsupported field')
			end
		end
		function tf = getTermIsSolved(expr,termIndices)
			termIndices = Expression.booleanCheck(termIndices);
			[fieldInds,LIs] = expr.lookup(termIndices);
			tf = arrayfun( @(fI,LI) all( getIsSolved( expr.(expr.fields{fI})(:,LI) ), 1), fieldInds,LIs );
		end
		function expr = deleteTerms(expr,termIndices)
			termIndices = Expression.booleanCheck(termIndices);
			[fieldInds,LIs] = expr.lookup(sort(termIndices)); % sort, so we can go in reverse order and preserve index meaning during the removals
			
			for k = numel(fieldInds) : -1 : 1 % go in reverse to avoid corrupting index meaning
				% Remove each entry in turn. Remove the whole column, to
				% support the multi-variable cases.
				expr.( expr.fields{fieldInds(k)} )(:,LIs(k)) = [];
			end
		end
		function [expr,changed] = simplifySplit(expr,parentLabel)
			
			% Make a list of all complex terms
			quants = expr.numTermsByType;
			% The first two quants are simple addition/subtraction. All the
			% rest are complex
			complexInds = sum(quants(1:2)) + 1 : sum(quants);
			numTerms_ = numel(complexInds);
			
			changed = numTerms_ > 0;
			if numTerms_ == 0
				return
			end
			
			% Look up some info on these
			[FIs,LIs] = expr.lookup(complexInds);
			
			% Grab all the variable sets and their range of values
			varSets = cell(numTerms_,1);
			for tInd = 1:numTerms_
				varSets{tInd} = expr.( expr.fields{FIs(tInd)} )(:,LIs(tInd));
			end
			naiveValueSets = expr.getPossibilities(complexInds);
			
			% Delete all of these terms from this expression
			expr = expr.deleteTerms(complexInds);
			% Now that this is done, we can safely mess with term indexing.
			
			% Now we're going to make an auxiliary variable, insert it into
			% the expression, and make a corresponding equation for this
			% substitution
			for tInd = 1:numTerms_
				
				% Construct the variable and initialize its values with our
				% naive expectation.
				auxVar = Variable.auxVarCreationHelper( naiveValueSets(tInd) );
				
				% Include this new variable in the current expression
				switch FIs(tInd)
					case {3,4} % term was positive
						expr = expr + auxVar;
					case {5,6} % term was negative
						% The calculated possibleValues from above captured
						% the sign, but for our purposes, we don't want
						% that
						auxVar.possibleValues = -auxVar.possibleValues;
						expr = expr - auxVar;
					otherwise
						error('not supported')
				end
				
				% Prepare an expression which can be set to zero to
				% represent this substitution equation
				%    -auxVar + <complex term> = 0
				auxExpr = Expression();
				auxExpr.varList_M = auxVar;
				switch FIs(tInd)
					case {3,5} % multiplication
						auxExpr.varList_P_times(:,1) = varSets{tInd};
					case {4,6} % division
						auxExpr.varList_P_divide(:,1) = varSets{tInd};
					otherwise
						error('not supported')
				end
				
				% And finally, create the equation
				expr = constructAndRecordAuxEq(expr,auxExpr,parentLabel);
				
			end
			
		end
	end
	methods
		function applyConstraint(expr,termIndex,allowedSet)
			
			% Look up the relevant content
			[fieldInd,localInd] = expr.lookup(termIndex);
			
			% If the term is subtracted, flip the sign of the allowed
			% values so we can disregard it in the following processing
			if ismember( fieldInd, [2,5,6] )
				allowedSet = -allowedSet;
			end
			
			% Extract the relevant variables (saves a bit of typing below)
			vars = expr.(expr.fields{fieldInd})(:,localInd);
			startingCardinality = prod(arrayfun( @(v) cardinality(v.possibleValues), vars ));
			
			% Handle each field type separately
			switch fieldInd
				case {1,2} % varList_P, varList_M
					% Only one variable
					vars(1).possibleValues = intersect( vars(1).possibleValues, allowedSet );
				case {3,4,5,6} % varList_P_times, varList_M_times, varList_P_divide, varList_M_divide
					% Two variables
					
					A = vars(1).possibleValues.expand();
					B = vars(2).possibleValues.expand();
					allowedValues = allowedSet.expand();
					% Determine which combinations of these lists of
					% numbers are feasible
					switch fieldInd
						case {3,5} % multiplication
							possibilitiesMatrix = A(:) .* B(:).';
						case {4,6} % multiplication
							possibilitiesMatrix = A(:) ./ B(:).';
					end
					compatibilityMatrix = ismember( possibilitiesMatrix, allowedValues );
					% This last operation also ensures that the results are
					% integers, since the allowed values must already be
					% integers.
					% Determine if thes variables belong to a common
					% uniqueness family. If so, enforce their uniqueness.
					if any(ismember(vars(1).uniqueFamilyIDs,vars(2).uniqueFamilyIDs))
						compatibilityMatrix = compatibilityMatrix & (A(:) ~= B(:).');
					end
					
					% Downselect the lists of values if there are any
					% values (on a per-variable basis) that are not
					% possible
					newSet1 = SetOfIntegers.makeList( A( any(compatibilityMatrix,2) ) );
					newSet2 = SetOfIntegers.makeList( B( any(compatibilityMatrix,1) ) );
					% Assign
					vars(1).possibleValues = newSet1;
					vars(2).possibleValues = newSet2;
				otherwise
					error('not supported')
			end
			
			% Determine if we changed anything...
			endingCardinality = prod(arrayfun( @(v) cardinality(v.possibleValues), vars ));
			if startingCardinality > endingCardinality
				fprintf('Constrained possibilities by 10^%.2f\n',log10(startingCardinality/endingCardinality));
			end
			
		end
	end
	methods (Access = private, Static)
		function termIndices_ = booleanCheck(termIndicesOrBool)
			if islogical(termIndicesOrBool)
				termIndices_ = find( termIndicesOrBool(:) );
			else
				termIndices_ = termIndicesOrBool;
			end
		end
	end
	methods (Access = private)
		function expr = constructAndRecordAuxEq(expr,auxExpr,parentLabel)
			
			if exist('parentLabel','var')
				sublabel = getExcelColumnLabel( numel(expr.auxEqs)+1 );
				eqLabel = sprintf('%s%s',parentLabel,sublabel);
			else
				eqLabel = '?'; % defer meaningful setting to later
			end
			auxEq = Equation(auxExpr,0,eqLabel);
			% The new equation will be gathered by the static/global
			% Equation behavior. We'll also record a copy on the
			% expression itself
			expr.auxEqs(end+1,:) = auxEq;
		end
	end
end