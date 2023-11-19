classdef Variable < handle
	
	properties
		label char = '';
		possibleValues (1,1) SetOfIntegers = SetOfIntegers(); % empty by default
	end
	methods % setters
		function set.possibleValues(var_,pV)
			% We should never assign an empty set... (i.e. an invalid
			% solution)
			assert( cardinality(pV)>0, 'Attempted to lock in an invalid solution');
			var_.possibleValues = pV;
		end
	end
	
	methods
		function exprC = plus(varA,B)
			% If this function was invoked, then A is a variable
			if isa(B,'Variable')
				% We'll represent A as an expression, and then defer to the
				% Expression's implementation
				exprA = Expression();
				exprA.varList_P = varA;
				exprC = exprA + B; % This is the real operation
			elseif isa(B,'Expression')
				% We can defer to the Expression's implementation and just
				% re-order these operands
				exprC = B + varA;
			else
				error('Unexpected operation with unknown type')
			end
		end
		function exprC = minus(varA,B)
			% If this function was invoked, then A is a variable
			assert( isa(B,'Variable') || isa(B,'Expression'), 'Second argument must be a Variable or an Expression' );
			
			% In either case, we'll convert A to an expression and defer to
			% the Expression's implementation of minus()
			exprA = Expression();
			exprA.varList_P = varA;
			exprC = exprA - B; % This is the real operation
		end
		function exprC = times(varA,B)
			% If this function was invoked, then A is a variable
			if isa(B,'Variable')
				% Create the expression representing the product of two
				% variables
				exprC = Expression();
				exprC.varList_P_times = [varA;B];
			elseif isa(B,'Expression')
				error('Multiplying a Variable and an Expression is not supported');
			else
				error('Unexpected operation with unknown type')
			end
		end
		function exprC = rdivide(varA,B) % normal division
			% If this function was invoked, then A is a variable
			if isa(B,'Variable')
				% Create the expression representing the division of two
				% variables
				exprC = Expression();
				exprC.varList_P_divide = [varA;B]; % normal division -> normal order
				
				% Since these variables have been divided, there's an
				% implicit constraint that the division yields an integer
				
				
				
			elseif isa(B,'Expression')
				error('Dividing a Variable by an Expression is not supported');
			else
				error('Unexpected operation with unknown type')
			end
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
		function disp(var)
			xSymbol = char(215);
			temp = compose(['%u',xSymbol], size(var));
			sizeStr = cat(2,'', temp{:} );
			sizeStr(end) = [];
			
			fprintf( '  %s Variables\n', sizeStr );
			for k = 1:numel(var)
				if var(k).getIsSolved()
					fprintf( '    %s = %d\n', var(k).label, var(k).possibleValues.ranges(1,1) );
				else
					fprintf( '    %s could be any of %s\n', var(k).label, var(k).possibleValues.toString() );
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