classdef Variable < handle
	
	properties
		label char = '';
		possibleValues (1,1) = SetOfIntegers(); % empty by default
		uniqueFamilyIDs (1,:) uint16 = uint16.empty(1,0); % One entry for each uniqueness group that this variable belongs to
	end
	methods % setters
		function set.possibleValues(var_,pV)
			
			% If the input is numeric instead of a set of integers, cast it
			% to the right type, out of convenience.
			if isnumeric(pV)
				pV = SetOfIntegers.makeList(pV);
			end
			
			% We should never assign an empty set... (i.e. an invalid
			% solution)
			assert( cardinality(pV)>0,...
				'Variable:invalidSolution',...
				'Attempted to lock in an invalid solution');
			
			var_.possibleValues = pV;
		end
	end
	
	methods (Access = public)
		% If these functions/operators were invoked, then we are confident
		% the first arument is a "Variable" because of matlab's dispatching
		% mechanisms. No type checking necessary
		function exprC = plus(varA,B)
			assert(isscalar(varA),'Arithmetic is only supported on scalar Variables');
			% We'll cast A to an expression and defer to the Expression's
			% implementation of addition
			exprA = Expression.fromVariable(varA);
			exprC = exprA + B;
		end
		function exprA = uminus(varA)
			assert(isscalar(varA),'Arithmetic is only supported on scalar Variables');
			% We'll cast A to an expression and defer to the Expression's
			% implementation of unitary minus
			exprA = -Expression.fromVariable(varA); % negative immediately
		end
		function exprC = minus(varA,B)
			assert(isscalar(varA),'Arithmetic is only supported on scalar Variables');
			% We'll cast A to an expression and defer to the Expression's
			% implementation of subtraction
			exprA = Expression.fromVariable(varA);
			exprC = exprA - B;
		end
		function exprC = times(varA,B)
			assert(isscalar(varA),'Arithmetic is only supported on scalar Variables');
			% We'll cast A to an expression and defer to the Expression's
			% implementation of multiplication
			exprA = Expression.fromVariable(varA);
			exprC = exprA * B;
		end
		function exprC = rdivide(varA,B) % normal division
			assert(isscalar(varA),'Arithmetic is only supported on scalar Variables');
			% We'll cast A to an expression and defer to the Expression's
			% implementation of multiplication
			exprA = Expression.fromVariable(varA);
			exprC = exprA / B;
		end
		function exprC = ldivide(varA,B)
			% Just swap the order
			exprC = rdivide(B,varA);
		end
		function exprC = mtimes(A,B)
			% Defer to non-matrix operation
			exprC = times(A,B);
		end
		function exprC = mrdivide(A,B)
			% Defer to non-matrix operation
			exprC = rdivide(A,B);
		end
		function exprC = mldivide(A,B)
			% Defer to non-matrix operation
			exprC = ldivide(A,B);
		end
		function eqC = eq(varA,B)
			% Try to form an equation
			eqC = Equation(varA,B);
		end
		function disp(vars)
			xSymbol = char(215);
			temp = compose(['%u',xSymbol], size(vars));
			sizeStr = cat(2,'', temp{:} );
			sizeStr(end) = [];
			
			fprintf( '  %s Variables\n', sizeStr );
			for k = 1:numel(vars)
				if vars(k).getIsSolved()
					fprintf( '    %s = %d\n', vars(k).label, vars(k).possibleValues.ranges(1,1) );
				else
					fprintf( '    %s could be any of %s\n', vars(k).label, vars(k).possibleValues.toString() );
				end
			end
			fprintf('\n');
		end
	end
	
	methods
		function tf = getIsSolved(var)
			% Support array of variables
			tf = false(size(var));
			for k = 1:numel(var)
				tf(k) = var(k).possibleValues.cardinality() == 1;
			end
		end
	end
	methods (Static)
		function auxVar = auxVarCreationHelper(initialValueSet)
			% Construct the variable
			auxVar = Variable();
			auxVar.label = sprintf('a%u',Variable.getNextAuxIndex());
			% Declare what it could be, based on the thing it's equal
			% to. This ensures the possibleValues is set at least
			% moderately well.
			auxVar.possibleValues = initialValueSet;
			% Record this new variable, for goot measure
			Variable.recordAuxVar(auxVar);
		end
	end
	
	methods (Static)
		function clearGlobal()
			Variable.generalVariableStorage('clear');
		end
		function ind = getNextAuxIndex()
			ind = Variable.generalVariableStorage('nextAuxInd');
		end
		function recordAuxVar(auxVar)
			Variable.generalVariableStorage('recordAux',auxVar);
		end
		function auxVarList = getAuxVars()
			auxVarList = Variable.generalVariableStorage('getAux');
		end
	end
	methods (Static, Access = private)
		function varargout = generalVariableStorage(mode,varargin)
			
			persistent auxVarCount auxVarList;
			if isempty(auxVarCount) || ~isa(auxVarList,'Variable') || strcmp(mode,'clear')
				auxVarCount = 0;
				auxVarList = Variable.empty(0,1);
				fprintf('Variable global settings have been reset\n')
				% If we were asked to clear, then we can terminate
				if strcmp(mode,'clear')
					return
				end
			end
			
			switch mode
				case 'nextAuxInd'
					auxVarCount = auxVarCount + 1;
					varargout{1} = auxVarCount;
				case 'recordAux'
					auxVarList(end+1,1) = varargin{1};
				case 'getAux'
					varargout = {auxVarList};
				otherwise
					error('Invalid usage');
			end
		end
		
	end
	
end