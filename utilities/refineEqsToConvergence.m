function eqList = refineEqsToConvergence(x,eqList)
	% Repeat this loop of manipulating equations until eventually nothing
	% changes.
	anyChanges = true;
	while anyChanges
		anyChanges = false;
		
		reportNaiveTradeSpaceSize(x)
		
		% Refine the domain
		for k = 1:numel(eqList)
			[eqList(k),changed] = eqList(k).refine();
			anyChanges = anyChanges || changed;
		end
		
		changed = UniquenessManager.enforceUniqueness();
		anyChanges = anyChanges || changed;
		
	end
end