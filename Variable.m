classdef Variable < handle
	
	properties (GetAccess = public, SetAccess = public)
		label          (1,:) char = '';
		possibleValues (1,1)      = SetOfIntegers(); % empty by default
	end
	methods % Setters
		function set.label(var_,label_)
			assert( ~Variable.getIsLocked(), 'Unexpected control flow, should not be making structural changes after state locking...' );
			var_.label = label_;
		end
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
	
	
	% * * * * * * * * * * * * * * * CONSTRUCTOR * * * * * * * * * * * * * *
	methods (Access = public)
		function vars = Variable(varargin)
			
			% Parse the size provided
			switch numel(varargin)
				case 0
					sz = [1,1];
				case 1
					sz = varargin{1};
				otherwise
					sz = cat(2, varargin{:} );
			end
			% I could do more error checking here... but I don't really
			% care to.
			
			assert( isvector(sz) && isnumeric(sz) && all(isfinite(sz)) &&...
				isreal(sz) && all(mod(sz,1)==0) && all(sz>=0),...
				'Invalid array size')
			
			% Handle empty arrays differently
			num = prod(sz);
			if num == 0
				% If the request was actually empty, just short-circuit on
				% that and don't record anything
				vars = Variable.empty(sz);
				return
			end
			
			% I found some guidance on making arrays of handle objects
			% https://www.mathworks.com/help/matlab/matlab_oop/creating-object-arrays.html
			temp(num,1) = vars;
			% It feels like this shouldn't be enough to sever the objects
			% into distinct instances, but apparently it is.
			
			% Reshape
			vars = reshape(temp,sz);
			
			% Record these objects
			% There seems to be one nuance with the above code that will
			% end up recording an extra scalar instance of our Variable
			% class, which is redundant to the first entry in the array
			% created. To avoid recording this as a distinct variable,
			% we'll skip the recordGeneralVar() if we recurred into this
			% constructor.
			stack = dbstack(1); % omit current scope
			if ~isempty(stack) && strcmp(stack(1).name,'Variable.Variable') % stack(1) is therefore parent scope
				return
			end
			Variable.recordGeneralVar(vars);
			
		end
	end
	% * * * * * * * * * * * * * * * CONSTRUCTOR * * * * * * * * * * * * * *
	
	
	% * * * * * * * * * * * * UNIQUENESS INFO STORAGE * * * * * * * * * * *
	properties (GetAccess = ?UniquenessManager, SetAccess = ?UniquenessManager)
		uniqueFamilyIDs (1,:) uint16 = uint16.empty(1,0); % One entry for each uniqueness group that this variable belongs to
	end
	methods % Setters
		function set.uniqueFamilyIDs(var_,familyIDs)
			assert( ~Variable.getIsLocked(), 'Unexpected control flow, should not be making structural changes after state locking...' );
			var_.uniqueFamilyIDs = familyIDs;
		end
	end
	% * * * * * * * * * * * * UNIQUENESS INFO STORAGE * * * * * * * * * * *
	
	
	% * * * * * * * * * OVERLOADED OPERATORS/FUNCTIONS * * * * * * * * * *
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
	% * * * * * * * * * OVERLOADED OPERATORS/FUNCTIONS * * * * * * * * * *
	
	
	% * * * * * * * * * * * * HELPER FUNCTIONS * * * * * * * * * * * * * *
	methods (Access = public)
		function tf = getIsSolved(vars)
			% Support array of variables
			tf = false(size(vars));
			for k = 1:numel(vars)
				tf(k) = vars(k).possibleValues.cardinality() == 1;
			end
		end
	end
	methods (Access = public, Static)
		function auxVar = auxVarCreationHelper(initialValueSet)
			% Construct the variable
			auxVar = Variable();
			auxVar.label = sprintf('a%u',Variable.getNextAuxIndex());
			% Declare what it could be, based on the thing it's equal
			% to. This ensures the possibleValues is set at least
			% moderately well.
			auxVar.possibleValues = initialValueSet;
			% Record this new variable, for good measure
			Variable.recordAuxVar(auxVar);
		end
	end
	% * * * * * * * * * * * * HELPER FUNCTIONS * * * * * * * * * * * * * *
	
	
	% * * * * * * * * * STATIC CLASS-WIDE MANAGEMENT * * * * * * * * * * *
	methods (Access = public, Static)
		% General state management
		function clearGlobal()
			Variable.generalVariableStorage('clear');
		end
		function lockStructure()
			Variable.generalVariableStorage('lock');
		end
		function unlockStructure()
			Variable.generalVariableStorage('unlock');
		end
		function isLocked = getIsLocked()
			isLocked = Variable.generalVariableStorage('getIsLocked');
		end
		function state = exportState()
			assert( Variable.getIsLocked(), 'The structure needs to be locked before exporting a state -> Variable.lockStructure()');
			state = Variable.generalVariableStorage('exportState');
		end
		function restoreState(state)
			assert( isa(state,'SolverState'), 'state must be a SolverState instance');
			assert( Variable.getIsLocked(), 'The structure needs to be locked while restoring a state -> Variable.lockStructure()');
			Variable.generalVariableStorage('restoreState',state);
		end
		
		% General variable handling (manual or auxiliary variables)
		function recordGeneralVar(arrayOfVars)
			Variable.generalVariableStorage('recordGen',arrayOfVars);
		end
		
		% Auxiliary variable handling
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
	methods (Access = private, Static)
		function varargout = generalVariableStorage(mode,varargin)
			
			persistent genVarList auxVarList lockID;
			notYetInit = ...
				~isa(genVarList,'Variable') || ...
				~isa(auxVarList,'Variable') || ...
				isempty(lockID);
			% If we're not initialized, or we need to reset, re-initialize
			% the persistent variables.
			if notYetInit || strcmp(mode,'clear')
				genVarList = Variable.empty(0,1);
				auxVarList = Variable.empty(0,1);
				lockID = nan;
				fprintf('Variable global settings have been reset\n')
				% If we were asked to clear, then we can terminate
				if strcmp(mode,'clear')
					return
				end
			end
			
			% The nan'iness of the lockID informs whether we're locked or
			% not.
			isLocked = ~isnan(lockID);
			
			% Operations which would alter the structural state of these
			% parameters are guarded by a check on isLocked.
			switch mode
				case 'getIsLocked'
					varargout{1} = isLocked;
				case 'lock'
					% If we're not already locked, we'll choose a new
					% lockID
					if ~isLocked
						sprev = rng('shuffle');
						lockID = randi(2^32);
						rng(sprev); % restore rng state
					end
				case 'unlock'
					lockID = nan; % Reset the lockID
				case 'exportState'
					% Error checking on lock state has already been done
					state = SolverState();
					state.lockID = lockID; % Make a copy of the current lockID, to compare upon importing
					% Extract all the variable states
					state.varStates = arrayfun( @(v) v.possibleValues, genVarList );
					% Return this state instance
					varargout{1} = state;
				case 'restoreState'
					% Verify the lockID still matches. Failure to match
					% indicates that the structure was unlocked, and thus
					% may not line up anymore.
					state = varargin{1};
					assert( isequal(state.lockID,lockID), 'The structure must have been unlocked and relocked since exporting the state. This is not allowed. Restoring a state must be done during the same period of lockdown as it was exported.' );
					assert( numel(state.varStates) == numel(genVarList), 'Something went wrong');
					% Restore the possibleValues of all managed variables
					for k = 1:numel(genVarList)
						genVarList(k).possibleValues = state.varStates(k);
					end
				
				case 'recordGen'
					enforceStateLock(isLocked);
					varList = varargin{1};
					N = numel(varList);
					genVarList(end+1:end+N,1) = varList(:);
				
				case 'nextAuxInd'
					varargout{1} = numel(auxVarList) + 1;
				case 'recordAux'
					enforceStateLock(isLocked);
					varList = varargin{1};
					N = numel(varList);
					auxVarList(end+1:end+N,1) = varList(:);
				case 'getAux'
					varargout = {auxVarList};
				
				otherwise
					error('Invalid usage');
			end
			
			function enforceStateLock(isLocked)
				assert( ~isLocked, 'Unexpected control flow. Variable has been locked down, and disallows making structural changes' )
			end
		end
	end
	% * * * * * * * * * STATIC CLASS-WIDE MANAGEMENT * * * * * * * * * * *
	
end