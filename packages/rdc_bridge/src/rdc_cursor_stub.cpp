// Fallback cursor capture for platforms built without FreeRDP.
//
// There is no session, so there is no remote pointer to report: everything
// reports the ordinary arrow so the application keeps using the platform's own
// cursor.

#include "rdc_cursor.h"

#include <cstring>

namespace rdc {

void InstallCursorCapture(rdpContext* context) { (void)context; }

void ResetCursor() {}

int32_t CursorInfo(rdc_cursor_info* out) {
  if (out == nullptr) {
    return RDC_ERR_BAD_ARGUMENT;
  }
  std::memset(out, 0, sizeof(*out));
  out->kind = RDC_CURSOR_DEFAULT;
  return RDC_OK;
}

int32_t CursorCopy(uint8_t* out, int32_t capacity) {
  (void)out;
  (void)capacity;
  return 0;
}

}  // namespace rdc
