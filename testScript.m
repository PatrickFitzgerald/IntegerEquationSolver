addpath('classes')
addpath('utilities')
addpath('solvers')

clear all

Variable.clearGlobal()
UniquenessManager.clearGlobal()

xsol=nan(10);
xsol(5:7,1)=[91;86;32];
xsol([1 2 6 8],2)=[9;60;94;55];
xsol(8,3)=10;
xsol([1 3],4)=[8;63];
xsol([1 5],5)=[37;12];
xsol(3,6)=30;
xsol(1,7)=97;
xsol([1 3 6 8],8)=[34;33;19;62];
xsol([3 6],9)=[25;38];

x = Variable(10,10);
for k = 1:numel(x)
	x(k).label = sprintf('x%u',k);
% 	x(k).label = sprintf('x03%u',k);
	if ~isnan( xsol(k) )
		x(k).possibleValues = SetOfIntegers.makeConstant( xsol(k) ); % constant value, already solved
	else
		x(k).possibleValues = SetOfIntegers.makeRange(1,100); % inclusive
	end
end
% for ii = 1:10
% 	for jj = 1:10
% 		x(ii,jj).label = sprintf('x(%02u,%02u)',ii,jj);
% 	end
% end

% Report the initial problem size
reportNaiveTradeSpaceSize(x);

% Declare that all entries of x will be mutually unique
UniquenessManager.declareUniqueFamily(x);

% Apply the uniqueness constraints
UniquenessManager.enforceUniqueness();

eqList = [
	x(  1) + x( 11) - x( 21) - x( 31) - x( 41) + x( 51) - x( 61) - x( 71) + x( 81) * x( 91) == 297;
	x(  2) + x( 12) * x( 22) + x( 32) - x( 42) + x( 52) - x( 62) + x( 72) - x( 82) - x( 92) == 3340;
	x(  3) * x( 13) - x( 23) - x( 33) + x( 43) + x( 53) + x( 63) + x( 73) - x( 83) + x( 93) == 4776;
	x(  4) + x( 14) + x( 24) - x( 34) * x( 44) + x( 54) - x( 64) - x( 74) - x( 84) - x( 94) == -1366;
	x(  5) - x( 15) + x( 25) - x( 35) - x( 45) * x( 55) - x( 65) + x( 75) - x( 85) + x( 95) == -310;
	x(  6) + x( 16) + x( 26) * x( 36) - x( 46) - x( 56) / x( 66) - x( 76) - x( 86) + x( 96) == 201;
	x(  7) * x( 17) - x( 27) + x( 37) - x( 47) + x( 57) / x( 67) + x( 77) - x( 87) + x( 97) == 510;
	x(  8) + x( 18) * x( 28) + x( 38) + x( 48) - x( 58) + x( 68) + x( 78) - x( 88) - x( 98) == 646;
	x(  9) + x( 19) + x( 29) - x( 39) + x( 49) - x( 59) - x( 69) - x( 79) + x( 89) - x( 99) == 88;
	x( 10) - x( 20) + x( 30) + x( 40) + x( 50) - x( 60) * x( 70) + x( 80) - x( 90) - x(100) == -2707;
	x(  1) + x(  2) * x(  3) / x(  4) + x(  5) + x(  6) + x(  7) - x(  8) + x(  9) - x( 10) == 1092;
	x( 11) - x( 12) * x( 13) + x( 14) - x( 15) + x( 16) - x( 17) + x( 18) + x( 19) - x( 20) == -3166;
	x( 21) - x( 22) - x( 23) - x( 24) + x( 25) * x( 26) - x( 27) + x( 28) + x( 29) + x( 30) == -36;
	x( 31) + x( 32) - x( 33) * x( 34) - x( 35) + x( 36) + x( 37) - x( 38) + x( 39) + x( 40) == -2921;
	x( 41) - x( 42) - x( 43) + x( 44) - x( 45) / x( 46) - x( 47) - x( 48) + x( 49) - x( 50) == -195;
	x( 51) + x( 52) - x( 53) + x( 54) + x( 55) - x( 56) * x( 57) + x( 58) + x( 59) - x( 60) == -1368;
	x( 61) - x( 62) + x( 63) + x( 64) + x( 65) * x( 66) + x( 67) - x( 68) - x( 69) + x( 70) == 172;
	x( 71) + x( 72) - x( 73) - x( 74) - x( 75) - x( 76) * x( 77) - x( 78) - x( 79) + x( 80) == -1789;
	x( 81) + x( 82) / x( 83) + x( 84) * x( 85) + x( 86) + x( 87) + x( 88) + x( 89) - x( 90) == 1632;
	x( 91) + x( 92) + x( 93) + x( 94) - x( 95) - x( 96) - x( 97) + x( 98) * x( 99) + x(100) == 1717;
];

% Now that all the equations are created, we'll assign them labels in an
% ordered fashion.
eqList = assignOrderedLabels(eqList);

% Do a first pass at refining
eqList = refineEqsToConvergence(eqList);
reportNaiveTradeSpaceSize(x)

%%

[solvedState,numRefineCalls] = depthFirstExploration(eqList,'most')
%%


eqList
x
Variable.getAuxVars()

function reportNaiveTradeSpaceSize(x)
	% Count the trade-space of x
	log10Possibilities = 0;
	for q = 1:numel(x)
		log10Possibilities = log10Possibilities + log10(cardinality(x(q).possibleValues));
	end
	fprintf('[\bCurrent trade-space is of size 10^%.2f]\b\n',log10Possibilities);
end
