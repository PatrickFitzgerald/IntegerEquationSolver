classdef UniquenessManager
	
	methods
		function this = UniquenessManager()
			error('This class is not intended to be instantiated');
		end
	end
	methods (Static)
		function clearGlobal()
			UniquenessManager.generalVariableStorage('clear');
		end
		function declareUniqueFamily(arrayOfVariables)
			assert(isa(arrayOfVariables,'Variable'),'Unique families are defined over sets of variables')
			% Get a new ID
			familyID = UniquenessManager.generalVariableStorage('getNextID');
			% Add this family ID to all the variables
			for k = 1:numel(arrayOfVariables)
				arrayOfVariables(k).uniqueFamilyIDs(1,end+1) = familyID;
			end
			% Record this list of variables internally
			UniquenessManager.generalVariableStorage('storeUniqueFamily',familyID,arrayOfVariables(:));
		end
		function [familyIDs,familyMembers] = getUniqueFamilies()
			familyMembers = UniquenessManager.generalVariableStorage('getAllFamilies');
			familyIDs = uint16(1:numel(familyMembers));
		end
		function changed = enforceUniqueness()
			
			changed = false;
			
			% Extract all families
			allFamilyMembers = UniquenessManager.generalVariableStorage('getAllFamilies');
			% Loop over them
			for fInd = 1:numel(allFamilyMembers)
				variables = allFamilyMembers{fInd};
				
				% For now, I'm only going to implement singleton
				% uniqueness. There's a lot more we can do here, but the
				% algorithms will become much more complicated, and likely
				% much slower...
				
				% Extract a list of all values which are represented in
				% solved variables.
				isSolved = getIsSolved(variables);
				solvedNumbers = arrayfun( @(v) v.possibleValues.expand(), variables(isSolved) ); % each returns a scalar, so concatenating is fine
				% Ensure the list is unique. If there are repeats, then
				% something went wrong and we have an invalid solution
				assert( numel(solvedNumbers) == numel(unique(solvedNumbers)),...
					'UniquenessManager:invalidSolution',...
					'The solver reached an invalid state: variables that are supposed to have unique values do not');
				
				totalStartingLog10 = 0;
				totalEndingLog10 = 0;
				
				% Ensure this list of numbers is disallowed from all other
				% variables in this family
				removeSet = SetOfIntegers.makeList(solvedNumbers);
				for vInd = find(~isSolved).'
					startingSet = variables(vInd).possibleValues;
					startingCardinality = cardinality(startingSet);
					% Remove solved numbers
					endingSet = SetOfIntegers.setSubtract(startingSet,removeSet);
					% Determine if we improved anything
					endingCardinality = cardinality(endingSet);
					if endingCardinality < startingCardinality
						totalStartingLog10 = totalStartingLog10 + log10(startingCardinality);
						totalEndingLog10   = totalEndingLog10   + log10(endingCardinality);
						% Assign the confined set
						variables(vInd).possibleValues = endingSet;
						changed = true;
					end
				end
				
				% Only report progress once per family
				if totalEndingLog10 < totalStartingLog10
					fprintf('Constrained possibilities by uniqueness by 10^%.2f\n',totalStartingLog10 - totalEndingLog10)
				end
				
			end
		end
	end
	methods (Static, Access = private)
		function varargout = generalVariableStorage(mode,varargin)
			
			persistent lastUniqueFamilyID uniqueFamilies;
			if isempty(lastUniqueFamilyID) || strcmp(mode,'clear')
				lastUniqueFamilyID = uint16(0);
				uniqueFamilies = cell(0,1);
				fprintf('UniquenessManager global settings have been reset\n')
				% If we were asked to clear, then we can terminate
				if strcmp(mode,'clear')
					return
				end
			end
			
			switch mode
				case 'getNextID'
					varargout = {lastUniqueFamilyID + 1};
				case 'storeUniqueFamily'
					familyID = varargin{1};
					varList = varargin{2};
					assert(lastUniqueFamilyID + 1 == familyID, 'Something went wrong');
					% Record the family members
					uniqueFamilies{familyID} = varList;
					% Increase the last ID used
					lastUniqueFamilyID = familyID;
				case 'getAllFamilies'
					varargout{1} = uniqueFamilies;
				otherwise
					error('Invalid usage');
			end
		end
		
	end
	
end