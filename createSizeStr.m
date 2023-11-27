function sizeStr = createSizeStr(size_)
	xSymbol = char(215);
	temp = compose(['%u',xSymbol], size_);
	sizeStr = cat(2,'', temp{:} );
	sizeStr(end) = [];
end