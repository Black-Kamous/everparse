#include <stdint.h>

typedef uint32_t FOO_ID;
typedef uint16_t BAR_ID;

#define FOO_MAJOR_VERSION 0
#define FOO_MINOR_VERSION 0

#define BAR_MAJOR_VERSION 123
#define BAR_MINOR_VERSION 42

typedef struct
  [[everparse::process(1)]]
  [[everparse::entrypoint]]
  [[everparse::parameter(uint32_t MessageBodyLength)]]
  [[everparse::where(MessageBodyLength == sizeof(this))]]
_FOO {
  FOO_ID RequestId;
  uint32_t MajorVersion
      [[everparse::constraint(MajorVersion == FOO_MAJOR_VERSION && MajorVersion == 0)]];
  uint32_t MinorVersion
      [[everparse::constraint(MinorVersion == MajorVersion),
        everparse::constraint(MinorVersion == 1)]];
  uint32_t MaxTransferSize
      [[everparse::constraint(MaxTransferSize <= MessageBodyLength)]];
} FOO, *PFOO;

typedef struct
[[
  everparse::process(1),
  everparse::entrypoint,
  everparse::parameter(uint32_t MessageBodyLength),
  everparse::where(MessageBodyLength == sizeof(this)),
]]
_BAR {
  BAR_ID RequestId;
  uint32_t MajorVersion
      [[everparse::constraint(MajorVersion == BAR_MAJOR_VERSION && MajorVersion == 0)]];
  uint32_t MinorVersion
      [[everparse::constraint(MinorVersion == MajorVersion),
	everparse::constraint(MinorVersion == 1)]];
  uint32_t MaxTransferSize
      [[everparse::constraint(MaxTransferSize <= MessageBodyLength)]];
} BAR, *PBAR;
