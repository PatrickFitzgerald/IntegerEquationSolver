% This function prepends each line with the indentStr, except the first
% line. If the last line is empty, it does not prepend anything there.
function indentedStr = hangingIndent(str,indentStr)
	
	isrow_ = @(s) isrow(s) || isempty(s);
	assert( ischar(str)       && isrow_(str),       'str needs to be a row charvector');
	assert( ischar(indentStr) && isrow_(indentStr), 'indentStr needs to be a row charvector');
	
	% Handle the empty edge case
	if isempty(str)
		% First line doesn't get indented
		indentedStr = str;
		return
	end
	% str has at least 1 character
	
	% Any newline characters (not at the end) should have indentation added
	% afterwards
	indentedStr = [... % this will automatically not indent the first line
		regexprep( str(1:end-1), '\n', ['\n',indentStr] ),...
		str(end)... % omitting the last element of str from the regexprep means terminal newlines won't match.
	];
	
end