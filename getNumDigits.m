function numDigits = getNumDigits(num)
	if num == 0
		numDigits = 1;
	elseif num > 0 && mod(num,1)==0
		numDigits = floor(log10(num))+1;
	else
		error('num must be a nonnegative integer');
	end
end