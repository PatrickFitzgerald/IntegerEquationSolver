classdef SolverState % not handle
	
	properties (GetAccess = public, SetAccess = ?Variable)
		lockID (1,1) = nan;
		varStates (:,1) SetOfIntegers = SetOfIntegers.empty(0,1);
	end
	properties (Access = public)
		equations Equation = Equation.empty(0,0);
	end
	
end