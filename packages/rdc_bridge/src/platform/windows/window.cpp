// Window control for the session.
//
// Borderless full screen rather than maximise: a maximised window keeps its
// title bar and borders, and those cost screen height and give the user a chrome
// bar to hit by accident at the top of the screen -- exactly where a remote
// desktop puts its own menus. The exact previous geometry is saved so leaving
// full screen puts the window back where it was.

#include "rdc_api.h"

#include "rdc_core.h"

#ifdef _WIN32
#include <windows.h>

#include <cstring>
#endif

namespace rdc {
namespace {

#ifdef _WIN32

HWND g_window = nullptr;

// Saved on the way into full screen, restored on the way out.
bool g_fullscreen = false;
LONG_PTR g_saved_style = 0;
LONG_PTR g_saved_ex_style = 0;
WINDOWPLACEMENT g_saved_placement = {};

/// Finds this process's top-level application window.
///
/// Enumerated on demand rather than captured once, for two reasons. The
/// platform glue registers during engine startup, which is before the runner
/// has finished creating and showing its frame window, so a handle taken then
/// is null. And the engine's own view handle is not it either: the runner
/// parents the Flutter view inside a frame of its own, so styling the view
/// changes nothing the user can see.
BOOL CALLBACK FindWindowProc(HWND window, LPARAM param) {
  DWORD process_id = 0;
  GetWindowThreadProcessId(window, &process_id);
  if (process_id != GetCurrentProcessId()) {
    return TRUE;
  }
  // Owned windows are dialogs and tool windows; the frame has no owner.
  if (GetWindow(window, GW_OWNER) != nullptr) {
    return TRUE;
  }
  *reinterpret_cast<HWND*>(param) = window;
  return FALSE;  // stop at the first match
}

HWND ResolveWindow() {
  HWND window = static_cast<HWND>(g_window);
  if (window != nullptr && IsWindow(window)) {
    return window;
  }

  HWND found = nullptr;
  EnumWindows(FindWindowProc, reinterpret_cast<LPARAM>(&found));
  if (found != nullptr) {
    // Remembered so the full-screen state and the saved geometry keep referring
    // to the same window across commands.
    g_window = found;
  }
  return found;
}

void EnterFullScreen(HWND window) {
  if (g_fullscreen) {
    return;
  }

  g_saved_style = GetWindowLongPtrW(window, GWL_STYLE);
  g_saved_ex_style = GetWindowLongPtrW(window, GWL_EXSTYLE);
  g_saved_placement.length = sizeof(g_saved_placement);
  if (!GetWindowPlacement(window, &g_saved_placement)) {
    return;
  }

  // Work out which monitor the window is on before the frame goes away, so a
  // multi-monitor setup goes full screen on the display the user is looking at
  // rather than on the primary one.
  MONITORINFO monitor = {};
  monitor.cbSize = sizeof(monitor);
  if (!GetMonitorInfoW(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST), &monitor)) {
    return;
  }

  /* WS_OVERLAPPEDWINDOW is the union of the caption, the thick frame, the
   * system menu, minimise and maximise boxes: clearing it in one go is the
   * concise way to say "no decorations at all". */
  SetWindowLongPtrW(window, GWL_STYLE, g_saved_style & ~WS_OVERLAPPEDWINDOW);
  SetWindowLongPtrW(window, GWL_EXSTYLE, g_saved_ex_style & ~WS_EX_DLGMODALFRAME);

  RECT before = {};
  GetWindowRect(window, &before);

  SetWindowPos(window, HWND_TOP, monitor.rcMonitor.left, monitor.rcMonitor.top,
               monitor.rcMonitor.right - monitor.rcMonitor.left,
               monitor.rcMonitor.bottom - monitor.rcMonitor.top,
               SWP_NOOWNERZORDER | SWP_FRAMECHANGED);

  RECT after = {};
  GetWindowRect(window, &after);
  Log("window: full screen; monitor %ld,%ld %ldx%ld; was %ld,%ld %ldx%ld; now %ld,%ld %ldx%ld",
      monitor.rcMonitor.left, monitor.rcMonitor.top,
      monitor.rcMonitor.right - monitor.rcMonitor.left,
      monitor.rcMonitor.bottom - monitor.rcMonitor.top, before.left, before.top,
      before.right - before.left, before.bottom - before.top, after.left, after.top,
      after.right - after.left, after.bottom - after.top);

  g_fullscreen = true;
}

void LeaveFullScreen(HWND window) {
  if (!g_fullscreen) {
    return;
  }

  SetWindowLongPtrW(window, GWL_STYLE, g_saved_style);
  SetWindowLongPtrW(window, GWL_EXSTYLE, g_saved_ex_style);
  SetWindowPlacement(window, &g_saved_placement);
  SetWindowPos(window, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);

  g_fullscreen = false;
}

#endif  // _WIN32

}  // namespace

void SetMainWindow(void* handle) {
#ifdef _WIN32
  g_window = static_cast<HWND>(handle);
#else
  (void)handle;
#endif
}

void RunWindowCommand(int32_t command) {
#ifdef _WIN32
  HWND window = ResolveWindow();
  if (window == nullptr) {
    Log("window: no handle; command %d ignored", command);
    return;
  }

  switch (command) {
    case RDC_WINDOW_MINIMIZE:
      // Leaving full screen first, so the restore below brings back a normal
      // window rather than a borderless one.
      LeaveFullScreen(window);
      ShowWindow(window, SW_MINIMIZE);
      break;
    case RDC_WINDOW_RESTORE:
      /* Restoring out of full screen is this library's to do, not the
       * system's: the full-screen window is neither minimised nor maximised --
       * its style was stripped and its rectangle set directly -- so SW_RESTORE
       * would leave it exactly as it is. LeaveFullScreen puts back the saved
       * geometry, which is the size the user is asking for. */
      if (g_fullscreen) {
        LeaveFullScreen(window);
      } else {
        ShowWindow(window, SW_RESTORE);
        SetForegroundWindow(window);
      }
      break;
    case RDC_WINDOW_TOGGLE_FULLSCREEN:
      if (g_fullscreen) {
        LeaveFullScreen(window);
      } else {
        EnterFullScreen(window);
      }
      break;
    case RDC_WINDOW_ENTER_FULLSCREEN:
      EnterFullScreen(window);
      break;
    case RDC_WINDOW_LEAVE_FULLSCREEN:
      LeaveFullScreen(window);
      break;
    default:
      break;
  }
#else
  (void)command;
#endif
}

bool IsWindowFullScreen() {
#ifdef _WIN32
  return g_fullscreen;
#else
  return false;
#endif
}

}  // namespace rdc
