classdef Expression % non-handle
	
	% NOTE: Any division symbol is interpreted as EXCLUSIVELY performing
	% division on valid, divisible inputs. For example
	%    (1/2) / (1/2) is NOT valid, because (1/2) is not valid division.
	% Another way of saying this is that division cannot be rearranged
	% across parentheses to circumvent divisibility constraints.
	
	% All variable lists are added (after their respective operations) with
	% their corresponding signs
	properties (GetAccess = public, SetAccess = private)
		signs     (1,:) double = double.empty(1,0); % +1 or -1
		termTypes (1,:) double = double.empty(1,0); % see description below
		termVars  (2,:)   cell = cell(2,0); % each column indicates the variables to be used in each term
		% The rows of `termVars` have different meanings (or are unused)
		% depending on which termType is listed
		% 
		%  Type  Meaning             Description
		%   1     vars{1}             no-op
		%   2     vars{1} * vars{2}   multiplication
		%   3     vars{1} / vars{2}   division
	end
	properties (GetAccess = public, SetAccess = ?Equation)
		auxEqs (:,1) Equation = Equation.empty(0,1);
	end
	properties (GetAccess = public, SetAccess = private, Dependent)
		numTerms;
	end
	methods % Getters
		function val = get.numTerms(expr)
			val = numel(expr.termTypes);
		end
	end
	
	
	% * * * * * * * * * OVERLOADED OPERATORS/FUNCTIONS * * * * * * * * * *
	% The overloaded operators depend on the matlab parsing engine to still
	% execute them following the standard order of operations
	methods (Access = public)
		% If these functions/operators were invoked, then we are confident
		% the first arument is a "Expression" because of matlab's
		% dispatching mechanisms. No type checking necessary
		function exprC = plus(exprA,B)
			assert(isscalar(exprA),'Arithmetic is only supported on scalar Expressions');
			
			if isa(B,'Variable')
				% Cast B to an expression
				exprB = Expression.fromVariable( B );
			elseif isa(B,'Expression')
				exprB = B;
			else
				error('Unexpected operation with unknown type')
			end
			% Both A and B are now expressions
			
			% Addition means concatenation of our term lists, with no
			% modification of the signs
			exprC = Expression();
			exprC.signs     = [exprA.signs,     exprB.signs    ];
			exprC.termTypes = [exprA.termTypes, exprB.termTypes];
			exprC.termVars  = [exprA.termVars,  exprB.termVars ];
			
			% Ensure we retain the auxiliary equations from both inputs
			exprC.auxEqs = [ exprA.auxEqs; exprB.auxEqs ];
			
		end
		function exprA = uminus(exprA)
			assert(isscalar(exprA),'Arithmetic is only supported on scalar Expressions');
			
			% Flip the signs
			exprA.signs = -exprA.signs;
			
		end
		function exprC = minus(exprA,B)
			
			% We'll entirely defer to uminus() and plus()
			exprC = exprA + (-B);
			
		end
		function exprC = times(exprA,B)
			assert(isscalar(exprA),'Arithmetic is only supported on scalar Expressions');
			
			% We'll cast the second input to an expression so this
			% implementation can be a bit more uniform
			if isa(B,'Variable')
				% Cast B to an expression
				exprB = Expression.fromVariable( B );
			elseif isa(B,'Expression')
				exprB = B;
			else
				error('Unexpected operation with unknown type')
			end
			% Both A and B are now expressions
			
			% In keeping with the note above regarding integer division
			% preceding normal order of operations (which only implicitly
			% matters here for multiplication), we'll replace non-signleton
			% expressions with an auxiliary variable to stand in their
			% place. This is effectively an alternative to distributing the
			% multiplication.
			
			% We'll replace anything "complex" with an auxiliary variable.
			% This means if we have more than one term, or anything more
			% complex than a no-op term. The simplify() function returns
			% the original expression if it was already simple.
			exprA = exprA.simplify();
			exprB = exprB.simplify();
			
			% Ensure that these expressions are ready for use... If
			% the request for this operation was weird, then these
			% expressions may still be empty. Instead of treating them as
			% zeros (i.e. no terms), I'll throw an error until it's
			% meaningful...
			assert( exprA.numTerms>0 && exprB.numTerms>0, 'Something odd happened. An argument of this binary operator yielded an empty expression...' );
			
			% Past this point, we are confident that both expressions have
			% exactly one no-op term, and a sign. Combining this is simple
			% now, tailored to multiplication
			exprC = Expression();
			exprC.signs(1) = exprA.signs(1) * exprB.signs(1); % signs multiply
			exprC.termTypes(1) = 2; % indicates multiplication
			exprC.termVars{1,1} = exprA.termVars{1,1};
			exprC.termVars{2,1} = exprB.termVars{1,1};
			
			% Retain auxiliary equations from constituents
			exprC.auxEqs = [ exprA.auxEqs; exprB.auxEqs ];
			
		end
		function exprC = rdivide(exprA,B)
			
			% This code is almost identical to times(). I've stripped out
			% all the comments from that implementation, and have
			% highlighted the modifications with the new comments herein.
			
			assert(isscalar(exprA),'Arithmetic is only supported on scalar Expressions');
			
			if isa(B,'Variable')
				exprB = Expression.fromVariable( B );
			elseif isa(B,'Expression')
				exprB = B;
			else
				error('Unexpected operation with unknown type')
			end
			
			exprA = exprA.simplify();
			exprB = exprB.simplify();
			
			assert( exprA.numTerms>0 && exprB.numTerms>0, 'Something odd happened. An argument of this binary operator yielded an empty expression...' );
			
			% Combining this is simple now, tailored to division
			exprC = Expression();
			exprC.signs(1) = exprA.signs(1) / exprB.signs(1); % signs divide (moot point)
			exprC.termTypes(1) = 3; % indicates division
			exprC.termVars{1,1} = exprA.termVars{1,1};
			exprC.termVars{2,1} = exprB.termVars{1,1};
			
			exprC.auxEqs = [ exprA.auxEqs; exprB.auxEqs ];
			
		end
		function exprC = ldivide(exprA,B)
			% A\B is the same as B/A. Defer to that implementation
			exprC = rdivide(B,exprA);
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
			% Try to form an equation. If it was formed with the ==
			% operator, then it was made by the user, not as an auxiliary
			% equation.
			isAuxiliary = false;
			eqC = Equation(exprA,B,isAuxiliary);
		end
		function disp(exprs)
			
			% Report size
			sizeStr = createSizeStr(size(exprs));
			fprintf( '  %s Expression\n', sizeStr );
			
			% Report each item, indenting them each, so they are
			% distinct from the size preface
			for k = 1:numel(exprs)
				rawStr = formatScalar(exprs(k));
				fprintf( '%s', indent(rawStr, '    ' ) );
			end
			% And an extra newline for good measure.
			fprintf('\n');
			
			function str = formatScalar(expr)
				
				% Extract the description of the expression and its
				% sub-equations
				[exprStr,eqsStr] = expr.toString();
				% Indent the subequations
				eqsStr = indent(eqsStr,'  ');
				% If not empty, prepend with a newline
				if ~isempty(eqsStr)
					eqsStr = sprintf('\n%s',eqsStr);
				end
				% Print to screen
				str = sprintf('Expression: %s%s\n', exprStr, eqsStr );
				
			end
		end
	end
	% * * * * * * * * * OVERLOADED OPERATORS/FUNCTIONS * * * * * * * * * *
	
	
	% * * * * * * * * * * * * HELPER FUNCTIONS * *  * * * * * * * * * * * *
	methods (Access = public)
		function [exprStr,eqsStr] = toString(expr)
			
			numTerms_ = expr.numTerms;
			
			if numTerms_ == 0
				exprStr = '0';
			else % at least one term
				% The initialization of `str` is performed at the end of
				% the first loop.
				for k = 1:numTerms_
					switch expr.termTypes(k)
						case 1 % no-op
							substr = expr.termVars{1,k}.label;
						case 2 % multiplication
							substr = [...
								expr.termVars{1,k}.label,...
								'*',...
								expr.termVars{2,k}.label...
							];
						case 3 % division
							substr = [...
								expr.termVars{1,k}.label,...
								'/',...
								expr.termVars{2,k}.label...
							];
						otherwise
							error('Unexpected term type')
					end
					
					if k == 1 % is first
						switch expr.signs(k)
							case +1
								exprStr = substr; % no preface
							case -1
								exprStr = ['-',substr]; % compact minus sign (implied unitary)
							otherwise
								error('Unexpected sign')
						end
					else % not first
						% Sign character can be more spaced out
						switch expr.signs(k)
							case +1
								sgn = ' + ';
							case -1
								sgn = ' - ';
							otherwise
								error('Unexpected sign')
						end
						exprStr = [ exprStr, sgn, substr ]; %#ok<AGROW>
					end
				end
			end
			
			% Prepare a representation of the contained equations
			eqsStr = ''; % a backup if 
			for k = 1:numel( expr.auxEqs )
				auxEqStr = expr.auxEqs(k).toString();
				if k == 1
					eqsStr = auxEqStr;
				else % k > 1
					% Concatenate, with a newline separating each one
					eqsStr = sprintf('%s\n%s',eqsStr,auxEqStr);
				end
			end
			
		end
		function sets = getPossibleValues(expr,termIndices)
			
			% If the indices weren't provided, combine all the terms
			% together and return that instead
			if ~exist('termIndices','var')
				% Ask for all terms, separately
				termIndices = 1:expr.numTerms;
				termResolvedSets = expr.getPossibleValues(termIndices);
				% Add the terms together
				sets = SetOfIntegers.makeConstant(0);
				for k = 1:expr.numTerms
					sets(1) = sets(1) + termResolvedSets(k);
				end
				return
			end
			
			% Now that we know the input argument exists, forcibly cast it
			% to a list of indices, instead of a boolean array
			termIndices = Expression.booleanCheck(termIndices);
			
			% In the normal flow, we'll loop over the requested terms, and
			% evaluate their effective possibleValues
			sets = repmat( SetOfIntegers(), size(termIndices) );
			for indInd = 1:numel(termIndices)
				tInd = termIndices(indInd);
				switch expr.termTypes(tInd)
					case 1 % no-op
						preSignSet = expr.termVars{1,tInd}.possibleValues;
					case 2 % multiplication
						preSignSet = ...
							expr.termVars{1,tInd}.possibleValues * ...
							expr.termVars{2,tInd}.possibleValues;
					case 3 % division
						preSignSet = ...
							expr.termVars{1,tInd}.possibleValues / ...
							expr.termVars{2,tInd}.possibleValues;
					otherwise
						error('unsupported term type')
				end
				% Include the effect of sign
				switch expr.signs(tInd)
					case +1
						sets(indInd) =  preSignSet; % as-is
					case -1
						sets(indInd) = -preSignSet; % flip sign
					otherwise
						error('Unexpected sign');
				end
			end
			
		end
		function tf = getTermIsSolved(expr,termIndices)
			
			termIndices = Expression.booleanCheck(termIndices);
			
			tf = false(size(termIndices));
			% Loop over each term and check.
			for indInd = 1:numel(tf)
				tInd = termIndices(indInd);
				switch expr.termTypes(tInd)
					case 1 % no-op
						% Only one variable. trivial
						isSolved = getIsSolved( expr.termVars{1,tInd} );
					case 2 % multiplication
						% Two variables. Solved if both are solved
						isSolved = ...
							getIsSolved( expr.termVars{1,tInd} ) && ...
							getIsSolved( expr.termVars{2,tInd} );
					case 3 % division
						% Like multiplication...
						v1 = expr.termVars{1,tInd};
						v2 = expr.termVars{2,tInd};
						isSolved = getIsSolved( v1 ) && getIsSolved( v2 );
						% But we have the additional constraint that
						% integer division is respected
						if isSolved
							possibleValues = v1.possibleValues / v2.possibleValues;
							assert( cardinality(possibleValues) == 1,...
								'Variable:invalidSolution', ...
								'Solution does not respect integer divisibilty.' );
							% If there's no error, then we're good.
							% proceed.
						end
					otherwise
						error('Unexpect term type');
				end
				tf(indInd) = isSolved;
			end
			
		end
		function expr = deleteTerms(expr,termIndices)
			
			termIndices = Expression.booleanCheck(termIndices);
			
			expr.signs(     termIndices) = [];
			expr.termTypes( termIndices) = [];
			expr.termVars(:,termIndices) = [];
		end
		% This assesses whether calling simplifyTermwise() can actually
		% lead to a simplified equation. For example, if this expression
		% represents an equation which was *generated* by simplifyTermwise,
		% then it can't be made simpler.
		function tf = canBeSplitAndSimplified(expr)
			
			% We'll make this implementation tolerant to the possibility
			% that parts of this equation may have been simplified through
			% other means (e.g. scalar-value substitution) which would only
			% lower the number of terms.
			% A non-simplifyable expression looks like one of (sign
			% independent):
			%    complex + simple
			%    complex
			%    simple
			%    0
			termIsSimple = expr.termTypes == 1;
			isAlreadySimple = sum(termIsSimple) <= 1 && sum(~termIsSimple) <= 1;
			tf = ~isAlreadySimple;
			
		end
	end
	methods (Access = public, Static)
		function expr = fromVariable(var_)
			assert(isa(var_,'Variable') && isscalar(var_),'The argument must be a scalar Variable');
			expr = Expression();
			expr.signs(1) = +1;
			expr.termTypes(1) = 1; % simple, no-op
			expr.termVars(:,1) = {[]}; % fill with empty
			expr.termVars{1,1} = var_;
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
		% Creates an auxiliary equation representing auxExpr == 0
		function expr = constructAndRecordAuxEq(expr,auxExpr)
			
			isAuxiliary = true;
			auxEq = Equation(auxExpr,0,isAuxiliary);
			% Record a copy of the new equation on the expression
			expr.auxEqs(end+1,:) = auxEq;
			
		end
	end
	% * * * * * * * * * * * * HELPER FUNCTIONS * *  * * * * * * * * * * * *
	
	
	% * * * * * * * * * * * EXPRESSION MANIPULATION  * * * * * * * * * * *
	methods (Access = public)
		% This simplifies a "complex" expression into a simple expression.
		% "Complex" expressions are those having more than one term, or
		% having any term which is more complicated than a no-op term.
		% Simple expressions, therefore, are expressions containing at most
		% 1 no-op term (any sign) and no other terms.
		function exprS = simplify(exprC) % Complex -> Simple
			
			% Determine whether this expression qualifies as being
			% "complex"
			isComplex = numel(exprC.termTypes)>1 || any(exprC.termTypes~=1);
			% Terminate early if not complex
			if ~isComplex
				exprS = exprC;
				return
			end
			
			% We achieve the simplification by creating an auxiliary
			% variable (and corresponding equation) to stand-in
			
			% We need a set of values to assign to the auxiliary variable,
			% as a starting point.
			naivePossibleValues = exprC.getPossibleValues(); % no extra inputs -> possible values of the entire expression, not term by term
			
			% Create the auxiliary variable
			auxVar = Variable.auxVarCreationHelper(naivePossibleValues);
			% The new simplified expression is now just this auxiliary
			% variable
			exprS = Expression.fromVariable( auxVar );
			% Make sure we retain pre-existing auxiliary equations
			exprS.auxEqs = exprC.auxEqs;
			
			% Prepare the auxiliary equation it will be formally defined by
			auxExpr = exprC - auxVar; % == 0
			exprS = exprS.constructAndRecordAuxEq( auxExpr ); % no parent label now, defer to later
			
		end
		% This does a similar operation as simplify(), but termwise. This
		% swaps out complex *terms*, which is any term which is not a no-op
		% term.
		function [expr,changed] = simplifyTermwise(expr)
			
			changed = false;
			
			% We're going to loop over each term and swap it out if needed.
			% This will keep the major structure of this expression intact
			for k = 1:expr.numTerms
				
				% Determine if this term is complex
				if expr.termTypes(k) == 1
					continue
				end
				% Term is complex
				
				% We need a set of values to assign to the auxiliary
				% variable, as a starting point.
				naivePossibleValues = expr.getPossibleValues(k); % look up only the term we're working on now
				% getPossibleValues() returns something that accounts for
				% the sign of the term. Since we're trying to substitute
				% out just that term, we don't want to retain the sign.
				% Cancel it off.
				switch expr.signs(k)
					case +1
						% Do nothing
					case -1
						naivePossibleValues = -naivePossibleValues; % flip sign
					otherwise
						error('Unexpected sign value');
				end
				
				% Create the auxiliary variable
				auxVar = Variable.auxVarCreationHelper(naivePossibleValues);
				
				
				% Make a new expression that will form the auxiliary
				% equation
				%    +existing term - auxVar == 0
				auxExpr = Expression();
				% Incorporate complex, existing term
				auxExpr.signs(1) = +1; % don't carry sign, so we can match the form of this aux equation
				auxExpr.termTypes(1)  = expr.termTypes(k); % copy current term
				auxExpr.termVars(:,1) = expr.termVars(:,k); % copy current term
				% Incorporate aux variable
				auxExpr.signs(2) = -1; % matching form of aux equation
				auxExpr.termTypes(2)  = 1; % simple, no-op
				auxExpr.termVars(:,2) = {[]}; % fill most rows with empty
				auxExpr.termVars{1,2} = auxVar; % overwrite first row with aux var
				
				% Prepare the auxiliary equation it will be formally defined by
				expr = expr.constructAndRecordAuxEq( auxExpr );
				
				
				% Substitute in this new auxiliary variable. The sign is
				% not part of the auxVar.
				expr.termTypes(k) = 1; % no-op
				expr.termVars(:,k) = {[]}; % empty existing
				expr.termVars{1,k} = auxVar; % insert simple, no-op term
				
				changed = true;
				
			end
			
		end
		function changed = applyConstraint(expr,termIndex,allowedSet)
			
			% We'll account for the sign of the term in question now, and
			% get to disregard it for the rest of the function
			switch expr.signs(termIndex)
				case +1
					% Do nothing
				case -1
					allowedSet = -allowedSet; % Flip the sign of the allowed set
				otherwise
					error('Unexpected sign value');
			end
			
			% For some bookkeeping and progress reporting, we'll record the
			% starting cardinality, so we can compare our ending state
			% later
			startingCardinality = cardinality( expr.getPossibleValues(termIndex) );
			
			% Extract the relevant variables (saves a bit of typing below)
			% (still a cell array).
			varC = expr.termVars(:,termIndex);
			% Tailor how we apply this to the type of operating being
			% represented
			switch expr.termTypes(termIndex)
				case 1 % no-op
					% Only one variable. Just confine what's already there
					varC{1}.possibleValues = intersect( varC{1}.possibleValues, allowedSet );
				case {2,3} % multiplication or division
					% Two variables
					
					% Map to actual lists of numbers
					A = varC{1}.possibleValues.expand();
					B = varC{2}.possibleValues.expand();
					allowedValues = allowedSet.expand();
					
					% Determine which combinations of these lists of
					% numbers are feasible
					switch expr.termTypes(termIndex)
						case 2 % multiplication
							possibilitiesMatrix = A(:) .* B(:).';
						case 3 % division
							possibilitiesMatrix = A(:) ./ B(:).';
					end
					compatibilityMatrix = ismember( possibilitiesMatrix, allowedValues );
					% This last operation also ensures that the results are
					% integers, since the allowed values must already be
					% integers.
					% If these variables are related through a uniqueness
					% constraint, and if so, enforce it.
					if UniquenessManager.areRelated(varC{2},varC{2})
						compatibilityMatrix = compatibilityMatrix & (A(:) ~= B(:).');
					end
					
					% Downselect the lists of values if there are any
					% values (on a per-variable basis) that are not
					% possible
					newSet1 = SetOfIntegers.makeList( A( any(compatibilityMatrix,2) ) );
					newSet2 = SetOfIntegers.makeList( B( any(compatibilityMatrix,1) ) );
					% Assign
					varC{1}.possibleValues = newSet1;
					varC{2}.possibleValues = newSet2;
					
				otherwise
					error('Unexpected term type')
			end
			
			% Determine if we changed anything...
			endingCardinality = cardinality( expr.getPossibleValues(termIndex) );
			changed = startingCardinality > endingCardinality;
			if changed
				fprintf('Constrained possibilities by 10^%.2f\n',log10(startingCardinality/endingCardinality));
			end
			
		end
	end
	% * * * * * * * * * * * EXPRESSION MANIPULATION  * * * * * * * * * * *
	
end