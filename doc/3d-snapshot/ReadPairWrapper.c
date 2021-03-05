#include "ReadPairWrapper.h"
#include "EverParse.h"
#include "ReadPair.h"
void ReadPairEverParseError(char *x, char *y, char *z);
static char* ReadPairStructNameOfErr(uint64_t err) {
	switch (EverParseFieldIdOfResult(err)) {
		case 1: return "Base._Pair";
		case 2: return "Base._Pair";
		case 3: return "Base._Mine";
		case 4: return "Base._Mine";
		case 5: return "BoundedSum._boundedSum";
		case 6: return "BoundedSum._boundedSum";
		case 7: return "BoundedSum.mySum";
		case 8: return "BoundedSumConst._boundedSum";
		case 9: return "BoundedSumConst._boundedSum";
		case 10: return "BoundedSumWhere._boundedSum";
		case 11: return "BoundedSumWhere._boundedSum";
		case 12: return "BoundedSumWhere._boundedSum";
		case 13: return "Color._coloredPoint";
		case 14: return "Color._coloredPoint";
		case 15: return "Color._coloredPoint";
		case 16: return "ColoredPoint._point";
		case 17: return "ColoredPoint._point";
		case 18: return "ColoredPoint._coloredPoint1";
		case 19: return "ColoredPoint._coloredPoint2";
		case 20: return "Derived._Triple";
		case 21: return "GetFieldPtr._T";
		case 22: return "GetFieldPtr._T";
		case 23: return "HelloWorld._point";
		case 24: return "HelloWorld._point";
		case 25: return "OrderedPair._orderedPair";
		case 26: return "OrderedPair._orderedPair";
		case 27: return "ReadPair._Pair";
		case 28: return "ReadPair._Pair"; 
		default: return "";
	}
}

static char* ReadPairFieldNameOfErr(uint64_t err) {
	switch (EverParseFieldIdOfResult(err)) {
		case 1: return "first";
		case 2: return "second";
		case 3: return "f";
		case 4: return "g";
		case 5: return "left";
		case 6: return "right";
		case 7: return "bound";
		case 8: return "left";
		case 9: return "right";
		case 10: return "__precondition";
		case 11: return "left";
		case 12: return "right";
		case 13: return "col";
		case 14: return "x";
		case 15: return "y";
		case 16: return "x";
		case 17: return "y";
		case 18: return "color";
		case 19: return "color";
		case 20: return "third";
		case 21: return "f1";
		case 22: return "f2";
		case 23: return "x";
		case 24: return "y";
		case 25: return "lesser";
		case 26: return "greater";
		case 27: return "first";
		case 28: return "second"; 
		default: return "";
	}
}

BOOLEAN ReadPairCheckPair(uint32_t* x, uint32_t* y, uint8_t *base, uint32_t len) {
	uint64_t result = ReadPairValidatePair(x, y, len, base, 0);
	if (EverParseResultIsError(result)) {
		ReadPairEverParseError(
	ReadPairStructNameOfErr(result),
			ReadPairFieldNameOfErr (result),
			EverParseErrorReasonOfResult(result));
		return FALSE;
	}
	return TRUE;
}
