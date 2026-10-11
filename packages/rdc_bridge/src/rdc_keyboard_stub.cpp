// Fallback keyboard capture for platforms built without FreeRDP.
//
// There is no session to hand keys to, so there is nothing to capture: the
// symbol exists so the library keeps exporting the whole ABI.

#include "rdc_keyboard.h"

namespace rdc {

bool SetKeyboardCapture(bool enabled) {
  (void)enabled;
  return false;
}

}  // namespace rdc
