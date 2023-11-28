function [solvedState,numRefineCalls] = depthFirstExploration(eqList, prioritizationMode)
	
	if ~exist('prioritizationMode','var')
		prioritizationMode = 'first';
	end
	
	% For good measure, to ensure that we're as refined as we can be, we'll
	% refine the equations once before starting.
	eqList = refineEqsToConvergence(eqList);
	
	% Ensure everything is locked and ready for state exporting/restoration
	Variable.lockStructure();
	
	% Get a list of the variables at play
	varList = Variable.getGenVars();
	
	% Run the recursive search
	numRefineCalls = 1;
	depth = 1;
	[wasSolved,solvedState,numRefineCalls] = recursiveExploration(eqList,varList, numRefineCalls,depth, prioritizationMode);
	assert(wasSolved, 'Somehow terminated without a solution...')
	
	% Unlock the structure
	Variable.unlockStructure();
	
end
function [wasSolved,solvedState,numRefineCalls] = recursiveExploration(eqList,varList, numRefineCalls,depth, prioritizationMode)
	
	% We're going to explore each set of possibilities as they present
	% themselves. We'll need a way to restore to this starting state when
	% we learn something definitive (either failure or success).
	state = Variable.exportState();
	state.equations = eqList;
	% This is our backup
	
	% We'll loop over all variables which are not already solved
	needsExploring = ~varList.getIsSolved;
	
	% This can be the point where we identify that everything is solved,
	% and can return
	if ~any(needsExploring)
		wasSolved = true;
		solvedState = state;
		% If we're already solved, then the solution was really found in
		% the previous scope, so we'll report that depth instead
		if GlobalParams.printSolverStatus
			fprintf(2,' * * * * * * * * * SOLUTION FOUND (depth=%u) * * * * * * * * * * \n',depth-1);
		end
		return
	end
	
	
	% We only need to explore the possibilities of one variable in this
	% scope, since sub-scopes can handle the other ones.
	switch lower(prioritizationMode)
		case 'first'
			vInd = find(needsExploring,1,'first'); % necessarily will find 1 match
		case 'last'
			vInd = find(needsExploring,1,'last'); % necessarily will find 1 match
		case 'random'
			indexOfTrues = cumsum(needsExploring);
			vInd = find( indexOfTrues == randi(indexOfTrues(end)),1,'first' ); % necessarily will find 1 match
		case {'fewest','most'}
			% Extract cardinalities
			cardinalities = arrayfun(@(v) cardinality(v), [varList.possibleValues]);
			% Obscure the items we don't need to explore
			cardinalities(~needsExploring) = nan;
			if strcmpi(prioritizationMode,'fewest')
				[~,vInd] = min(cardinalities);
			else % most
				[~,vInd] = max(cardinalities);
			end
		otherwise
			error('Unknown prioritizationMode');
	end
	
	
	% Extract the list of values that this variable can currently take.
	% We'll try all of these out independently.
	var_ = varList(vInd);
	possibleValueList = var_.possibleValues.expand();
	
	% Loop over possible value
	for pvInd = 1:numel(possibleValueList)
		
		% Assign a scalar possible value, i.e. hypothesize locking it
		% in, assuming it's correct.
		pv = possibleValueList(pvInd);
		var_.possibleValues = pv;
		% This on its own cannot produce an error, since we're
		% assigning a scalar.
		
		% However, this can lead to inconsistencies, which we can catch
		% with a try-catch block.
		
		try
			% Record this operation
			numRefineCalls = numRefineCalls + 1;
			% Test for inconsistencies, and refine the equations
			eqList = refineEqsToConvergence(eqList); % eqList captures the refined equations
			% If this succeeds, then we know we can push this
			% assumption harder, recursively. If it fails, then we've
			% gone too far, and learned that this assumption (combined
			% with all parent function calls' assumptions) is invalid.
		catch err
			switch err.identifier
				case 'Variable:invalidSolution'
				case 'Expression:invalidSolution'
				case 'UniquenessManager:invalidSolution'
				otherwise
					% If an unexpected error gets thrown, then we'll
					% want the user to see it.
					rethrow(err);
			end
			% If we're running here, then the assumption was invalid,
			% and we can move onto the next one. Since we didn't find a
			% solution, we haven't learned anything about the initial
			% state being flawed until we try out ALL the
			% possibilities.
			% Restore the state to the original state so we can undo
			% this latest assumption
			Variable.restoreState(state);
			eqList = state.equations;
			continue
		end
		
		% If we're still running here, then we haven't proven this
		% assumption as invalid yet. We can recur to further test the
		% remaining variables. If by chance we've arrived at the
		% solution from this operation, then it will be recognized
		% inside this next function call
		[wasSolved_,solvedState_,numRefineCalls] = recursiveExploration(...
			eqList,... % use the latest refined equations consistent with this latest assumption
			varList,... % pass this along
			numRefineCalls,... % pass this along
			depth+1,... % increment the depth
			prioritizationMode... % pass this along
		);
		% Assess the results to determine how we proceed
		if wasSolved_
			% Update the return values and halt, woo!
			wasSolved = true;
			solvedState = solvedState_;
			return
		end
		% In most cases, we did not solve the problem. So, before we
		% proceed to the next hypothesis, we'll reset the state.
		Variable.restoreState(state);
		eqList = state.equations;
		continue % unnecessary, but better symmetry with other "failure" case inside try-catch
		
	end
	
	% If we've made it this far and have not returned, then we have only
	% seen failures. If we failed for every possible value, then the
	% starting state must have been flawed. We'll report that.
	wasSolved = false;
	solvedState = [];
	if GlobalParams.printSolverStatus
		fprintf(2,'Dead end found (depth=%u, #refine=%u)\n',depth,numRefineCalls);
	end
	
end