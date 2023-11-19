% This function converts a counting number into what Excel would label that
% column:
% 1 -> 'a'
% 2 -> 'b'
% 26 -> 'z'
% 27 -> 'aa'
% 52 -> 'az'
% 53 -> 'ba'
% 
function str = getExcelColumnLabel(num)
	% It appears I can't really use naive base conversion, since that would
	% interpret `a` as 0, which means that `aa` is just 00=0 which would be
	% equivalent to `a` = 0...
	% If anything, it appears the leading character is interpreted as base
	% 27 (where 0 is blank) and all the trailing characters are base 26
	% (where 0 is a)
	
	letters = char(96+(1:26));
	
	% I think I'll just be lazy for now.
	if num <= 0 || mod(num,1)~=0
		error('Invalid number, must be positive integer');
	elseif num <= 26
		str = letters(num);
	elseif num <= 702
		digit1 = floor((num-1)/26); % at least 1
		digit2 = num - digit1*26;
		str = letters([digit1,digit2]);
	else
		error('large numbers not supported right now')
	end
	
end