classdef SetOfIntegers % not handle
	
	properties (GetAccess = public, SetAccess = private)
		ranges (:,2) = nan(0,2); % each row is [start,stop] (inclusive)
		% all rows are disjoint. rows will be sorted for convenience
	end
	
	methods (Access = public)
		function setC = plus(setA,setB) % assumes no shared variables
			% There are more efficient ways to combine these, but this is
			% by far the simplest
			
			% Independent sets plus each other have their mins add to
			% produce the new min, and their maxes add to produce the new
			% max. We apply this logic on the simple ranges of A,B pairwise
			setCRanges = setA.ranges.' + permute(setB.ranges.',[1,3,2]); % dim1 = start,stop dimension. dim2 is used for each simple range in A. dim3 is used for each simple range in B
			setCRanges = reshape( setCRanges, 2,[] ).'; % get back to dim1 as simple ranges, and dim2 as start,stop dimension
			% This needs simplification before we can yield
			setC = SetOfIntegers();
			setC.ranges = SetOfIntegers.simplifyRanges(setCRanges);
		end
		function setB = uminus(setA)
			setB = SetOfIntegers();
			% Simple ranges like [a,b] become [-b,-a]
			% The order of simple ranges flips since more positive items
			% are now more negative.
			setB.ranges = flipud(-fliplr(setA.ranges));
		end
		function setC = minus(setA,setB) % assumes no shared variables
			% This offloads the complex operations to plus() and uminus()
			setC = setA + (-setB);
		end
		function setC = times(setA,setB) % assumes no shared variables
			expandedOptions = setA.expand() .* setB.expand().';
			setC = SetOfIntegers.makeList( unique(expandedOptions(:)) );
		end
		function setC = mtimes(setA,setB) % assumes no shared variables
			% defer to non-matrix multiply
			setC = times(setA,setB);
		end
		function setC = rdivide(setA,setB) % assumes no shared variables
			expandedOptions = setA.expand() ./ setB.expand().';
			% Remove non-integers
			remove = mod(expandedOptions,1)~=0; % this also catches inf values, since mod(inf,1)=nan
			expandedOptions(remove) = [];
			setC = SetOfIntegers.makeList( unique(expandedOptions(:)) );
		end
		function setC = ldivide(setA,setB) % assumes no shared variables
			% Defer to rdivide by swapping order
			setC = rdivide(setB,setA);
		end
		function setC = mrdivide(setA,setB) % assumes no shared variables
			% Defer to non-matrix variant
			setC = rdivide(setA,setB);
		end
		function setC = lrdivide(setA,setB) % assumes no shared variables
			% Defer to non-matrix variant
			setC = ldivide(setA,setB);
		end
		
		function setB = confine(setA,lower,upper) % confines (inclusive)
			% We'll confine each simple range independently
			ranges_ = setA.ranges;
			ranges_(:,1) = max( ranges_(:,1), lower );
			ranges_(:,2) = min( ranges_(:,2), upper );
			% Remove any ranges that became invalid
			valid = ranges_(:,1) <= ranges_(:,2);
			setB = SetOfIntegers();
			setB.ranges = ranges_(valid,:);
		end
		function setC = intersect(setA,setB)
			% The complement of intersection is the union of the
			% complements.
			compARanges = SetOfIntegers.setComplement( setA.ranges );
			compBRanges = SetOfIntegers.setComplement( setB.ranges );
			compCRanges = SetOfIntegers.simplifyRanges( [compARanges; compBRanges] ); % simplifyRanges acts as union
			setC = SetOfIntegers();
			setC.ranges = SetOfIntegers.setComplement( compCRanges );
		end
		function num = cardinality(set)
			num = sum( diff(set.ranges,[],2)+1 );
		end
		function vec = expand(set)
			vec = nan(1,set.cardinality());
			last = 0;
			for k = 1:size(set.ranges,1)
				range = set.ranges(k,:);
				quant = range(2) - range(1) + 1;
				vec( last + (1:quant) ) = range(1) : range(2);
				last = last + quant;
			end
		end
		function disp(set)
			for sInd = 1:numel(set)
				fprintf('     Integer set: %s\n',set(sInd).toString())
			end
		end
		function str = toString(set)
			% This converts the list to a friendly format
			assert( isscalar(set), 'Can only stringify one set at a time')
			if ~isempty(set.ranges)
				strings = arrayfun( @(r1,r2) {formatRange(r1,r2)}, set.ranges(:,1), set.ranges(:,2) );
				label = cat(2,'',strings{:});
				label = label(1:end-2); % remove trailing ", "
			else
				label = '';
			end
			
			str = sprintf('{%s}',label);
			
			function str = formatRange(r1,r2)
				if r1 == r2
					str = sprintf('%d, ',r1);
				else
					str = sprintf('%d:%d, ',r1,r2);
				end
			end
		end
	end
	methods (Access = public, Static)
		function set = makeConstant(val)
			assert( mod(val,1)==0, 'Value must be an integer')
			set = SetOfIntegers();
			set.ranges = [val,val];
		end
		function set = makeRange(lower,upper)
			assert( mod(lower,1)==0 && mod(upper,1)==0, 'Values must be integers')
			if lower <= upper
				set = SetOfIntegers();
				set.ranges = [lower,upper];
			else % not valid
				set = SetOfIntegers(); % empty by default
			end
		end
		function set = makeList(vecOfValues)
			vecOfValues = vecOfValues(:);
			assert( all( mod(vecOfValues,1)==0 ), 'Values must be integers')
			set = SetOfIntegers();
			set.ranges = SetOfIntegers.simplifyRanges( repmat( vecOfValues, 1,2 ) );
		end
		function setC = setSubtract(setA,setB) % elements of A which appear in B are removed
			setA_ranges = SetOfIntegers.setComplement(setA.ranges);
			
			% simplifyRanges() is really performing a union on the existing
			% simple sets
			union = SetOfIntegers.simplifyRanges( [ setA_ranges; setB.ranges ] );
			setC = SetOfIntegers();
			setC.ranges = SetOfIntegers.setComplement( union );
		end
	end
	methods (Access = private, Static)
		function ranges = simplifyRanges(ranges)
			
			% Sort the input ranges so we can simplify our work in the
			% loop. This also lets us reuse this input as working space.
			ranges = sortrows(ranges);
			
			% Handle some edge cases
			if size(ranges,1) <= 1 % size == 0 or 1, already simplified
				return
			end
			
			workingRangeInd = 1;
			for rInd = 2:size(ranges,1) % at least 2 ranges
				% Each iteration of this loop adds the rInd'th simple range
				% (which necessarily has not been modified since sorting).
				% If this range starts after the previous one ends, then it
				% is distinct. If it overlaps or immediately neighbors the
				% previous range, then we merge the ranges.
				if ranges(rInd,1) <= ranges(workingRangeInd,2)+1 % merge
					% Sortedness ensures that we don't need to modify the
					% start value (either matches or is lower).
					% Just grow upper bound.
					ranges(workingRangeInd,2) = max( ranges(workingRangeInd,2), ranges(rInd,2) );
				else % start new
					workingRangeInd = workingRangeInd + 1;
					ranges(workingRangeInd,:) = ranges(rInd,:); % take as is. can be grown afterwards
				end
			end
			
			% We've added everything. Truncate to what we actually used.
			ranges = ranges(1:workingRangeInd,:);
			
		end
		function ranges_ = setComplement(ranges) % performs setSubtract( [all integers], setA )
			% Handle the empty set
			if isempty(ranges)
				ranges_ = [-inf,inf];
				return
			end
			% Now we know there's at least one simple range
			
			if isfinite(ranges(1)) && isfinite(ranges(end)) % finite range becoming infinite
				% We know the simple sets in A are disjoint and not neighbors,
				% so one outside each range is not inside A.
				ranges_ = nan( size(ranges,1)+1, 2 ); % one longer
				ranges_( 1, 1 ) = -inf;
				ranges_( 1:end-1, 2 ) = ranges(:,1) - 1; % start minus 1 is the end   of the previous complement
				ranges_( 2:end-0, 1 ) = ranges(:,2) + 1; % end   plus  1 is the start of the next     complement
				ranges_( end, 2 ) = +inf;
			elseif ~isfinite(ranges(1)) && ~isfinite(ranges(end)) % infinite range becoming finite
				ranges_ = nan( size(ranges,1)-1, 2 ); % one shorter
				ranges_(:,1) = ranges(1:end-1,2) + 1;
				ranges_(:,2) = ranges(2:end-0,1) - 1;
			else
				error('This function does not support semi-infinite bounds');
			end
		end
	end
	
end