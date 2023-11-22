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