// Window control where there is no window system to control.
//
// The commands do nothing and the state is always "not full screen", which is
// the truth: nothing here can make a window fill a screen. Keeping the symbols
// is what lets the rest of the library go on compiling and exporting the whole
// ABI on a platform that has not been implemented yet.

#include "platform/platform.h"

namespace rdc {

void SetMainWindow(void* native_window_handle) {
  (void)native_window_handle;
}

void RunWindowCommand(int32_t command) {
  (void)command;
}

bool IsWindowFullScreen() {
  return false;
}

}  // namespace rdc
