

#include "BF.h"

static inline uint64_t
ValidateDummyEmp(
  uint8_t *Ctxt,
  void
  (*Err)(
    EverParseString x0,
    EverParseString x1,
    EverParseString x2,
    uint8_t *x3,
    uint8_t *x4,
    uint64_t x5
  ),
  uint8_t *Input,
  uint64_t StartPosition
)
/*++
    Internal helper function:
        Validator for field _dummy_emp
        of type BF._dummy
--*/
{
  /* Validating field emp */
  uint64_t positionAfterDummy = StartPosition;
  if (EverParseIsSuccess(positionAfterDummy))
  {
    return positionAfterDummy;
  }
  Err("_dummy",
    "_dummy_emp",
    EverParseErrorReasonOfResult(positionAfterDummy),
    Ctxt,
    Input,
    StartPosition);
  return positionAfterDummy;
}

uint64_t
BfValidateDummy(
  uint8_t *Ctxt,
  void
  (*Err)(
    EverParseString x0,
    EverParseString x1,
    EverParseString x2,
    uint8_t *x3,
    uint8_t *x4,
    uint64_t x5
  ),
  uint8_t *Input,
  uint64_t InputLength,
  uint64_t StartPosition
)
{
  /* Field _dummy_emp */
  uint64_t positionAfterDummy = ValidateDummyEmp(Ctxt, Err, Input, StartPosition);
  if (EverParseIsSuccess(positionAfterDummy))
  {
    return positionAfterDummy;
  }
  Err("_dummy",
    "emp",
    EverParseErrorReasonOfResult(positionAfterDummy),
    Ctxt,
    Input,
    StartPosition);
  return positionAfterDummy;
}

void BfReadDummy(uint8_t *Input, uint64_t Pos)
{
  
}

