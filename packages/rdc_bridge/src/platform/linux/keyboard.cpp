// Keyboard capture on Linux: there is nothing here for this process to take,
// and this file exists to say so rather than to look like an oversight.
//
// The Windows implementation does two things. It takes the keys Windows acts on
// itself -- the Windows key, Alt+Tab, and the rest -- and it detaches the local
// input method so the host's does the composing. Neither has a counterpart:
//
//   * Those keys belong to the window manager, which takes them before the
//     application is asked. A client that wanted them would have to grab the
//     whole keyboard, including the keys the user needs to leave the window,
//     which is strictly worse than the ordinary path. Under Wayland the
//     compositor does not permit it at all.
//   * There is no per-window input method to detach. The input method is the
//     compositor's and the engine's business; switching it off from here would
//     be reaching into something this process does not own.
//
// So the ordinary path is the whole path: every key reaches the session through
// Flutter as a scancode, and the local shortcuts stay local. The session works;
// it just does not additionally capture the desktop's own keys.

#include "platform/platform.h"

namespace rdc {

bool SetKeyboardCapture(bool enabled) {
  (void)enabled;
  return false;
}

}  // namespace rdc
