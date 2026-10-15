// Keyboard capture on a platform that has no implementation of it yet.
//
// Nothing is taken from the local system and nothing is handed to the session,
// so the ordinary keyboard path is all there is: every key goes through the
// application as usual, and the keys the local system acts on stay with it.
// The session still works; it just cannot be driven the way a real desktop can.
//
// The symbol exists so the library keeps exporting the whole ABI.

#include "platform/platform.h"

namespace rdc {

bool SetKeyboardCapture(bool enabled) {
  (void)enabled;
  return false;
}

}  // namespace rdc
