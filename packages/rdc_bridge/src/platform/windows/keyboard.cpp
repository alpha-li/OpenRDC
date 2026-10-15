// Hands the session the keys Windows would otherwise keep for itself.
//
// Without this a remote desktop cannot be driven from the keyboard the way a
// real one can. Two separate things go wrong:
//
//   * The Windows key, Alt+Tab, Alt+Esc, Ctrl+Esc, Alt+F4 and the like are
//     consumed by the local system before any application sees them, so they
//     can never reach the host.
//   * A local input method that is switched on takes the keystrokes to compose
//     with. A user typing Chinese sees a candidate window appear on *their*
//     machine and the remote machine receives nothing at all.
//
// The answer is in two halves, and both are needed:
//
//   * A low-level keyboard hook that takes the keys in the table below and
//     queues them for the session instead of letting Windows act on them.
//   * The local input method detached from this process's windows, so keys
//     arrive as ordinary key messages and the *host's* input method does the
//     composing. That is what keeps the remote keyboard indicator, the remote
//     candidate window and what actually appears on the remote screen
//     consistent with one another.
//
// Only keys Windows would act on itself are taken. Everything else keeps
// flowing through the application (Flutter -> Dart -> scancodes), so no key is
// ever delivered twice and the client's own shortcuts keep working.

#include "platform/platform.h"

#include <vector>

#include "rdc_core.h"
#include "rdc_session.h"

#ifdef _WIN32
#include <windows.h>

#include <imm.h>
#endif

namespace rdc {

#ifdef _WIN32
namespace {

HHOOK g_hook = nullptr;
bool g_capture_on = false;

/// The modifiers as the hook has seen them.
///
/// Tracked here rather than asked of the system with GetAsyncKeyState, because
/// the hook runs before the key is delivered anywhere: the system's own view is
/// what this is trying to get ahead of.
bool g_ctrl = false;
bool g_alt = false;

/// Windows whose input method was detached, and what to put back.
///
/// Restoring is not optional. The rest of the application is full of text
/// fields -- the connection search box, the PC editor -- and a window left
/// without its input method cannot be typed into in Chinese at all.
std::vector<std::pair<HWND, HIMC>> g_detached;

/// The foreground window at the last hook call, so the detach can be re-applied
/// when focus moves to a window that did not exist when it ran.
HWND g_last_foreground = nullptr;

bool IsOurProcess(HWND window) {
  DWORD process_id = 0;
  GetWindowThreadProcessId(window, &process_id);
  return process_id == GetCurrentProcessId();
}

/// Detaches the input method from one window. False when it had none to detach.
bool DetachWindow(HWND window) {
  HIMC context = ImmAssociateContext(window, nullptr);
  if (context == nullptr) {
    return false;
  }
  g_detached.emplace_back(window, context);
  return true;
}

BOOL CALLBACK DetachChildProc(HWND window, LPARAM param) {
  if (DetachWindow(window)) {
    ++*reinterpret_cast<int*>(param);
  }
  return TRUE;
}

BOOL CALLBACK DetachTopLevelProc(HWND window, LPARAM param) {
  if (!IsOurProcess(window)) {
    return TRUE;
  }
  if (DetachWindow(window)) {
    ++*reinterpret_cast<int*>(param);
  }
  // The focused window is usually a child of the frame -- the engine's view --
  // and that is the one whose input method actually matters.
  EnumChildWindows(window, DetachChildProc, param);
  return TRUE;
}

/// Detaches the input method from every window this process owns. Returns how
/// many had one.
int DetachInputMethod() {
  int count = 0;
  EnumWindows(DetachTopLevelProc, reinterpret_cast<LPARAM>(&count));
  return count;
}

/// Same, for one window and its children: what the hook calls when focus lands
/// on a window created after the capture was turned on.
void DetachWindowTree(HWND window) {
  int ignored = 0;
  DetachWindow(window);
  EnumChildWindows(window, DetachChildProc, reinterpret_cast<LPARAM>(&ignored));
}

void RestoreInputMethod() {
  for (const auto& entry : g_detached) {
    if (IsWindow(entry.first)) {
      ImmAssociateContext(entry.first, entry.second);
    }
  }
  g_detached.clear();
}

/// Whether this key is one Windows would act on itself, and therefore has to be
/// taken and given to the session instead.
///
/// Deliberately a short list. Anything taken here stops reaching the
/// application, so every entry has to come with a local action it is preventing;
/// a key added "just in case" makes the session take a key the application
/// wanted for nothing.
///
/// Ctrl and Alt are never taken on their own account: Dart recognises the
/// client's own shortcuts (Ctrl+Alt+Home, Ctrl+Alt+Enter) from their state, and
/// needs to see them to do it.
///
/// Ctrl+Alt+Del is not here because it cannot be: Windows reserves it and no
/// hook sees it. That is what the connection bar's own Send Ctrl+Alt+Del button
/// exists for.
bool IsWindowsKey(bool alt, bool ctrl, DWORD virtual_key) {
  switch (virtual_key) {
    case VK_LWIN:
    case VK_RWIN:
      // Taken on its own account, which is what stops the Start menu. Holding
      // the key back also means the shell never sees a Windows key go down, so
      // the combinations built on it -- Win+D, Win+E, Win+Space -- cannot fire
      // locally either; the remote still assembles them, from this key and from
      // the ordinary keys Dart sends.
      return true;
    case VK_TAB:
      return alt;  // Alt+Tab, Alt+Shift+Tab
    case VK_ESCAPE:
      return alt || ctrl;  // Alt+Esc, Ctrl+Esc, Ctrl+Shift+Esc
    case VK_F4:
      return alt;  // Alt+F4
    case VK_SPACE:
      // Alt+Space opens the window's system menu; Ctrl+Space switches the local
      // input method, and which machine's input method is in use is the remote
      // machine's business.
      return alt || ctrl;
    case VK_SNAPSHOT:
      return true;  // the local screen is not what the user is looking at
    default:
      return false;
  }
}

void TrackModifiers(DWORD virtual_key, bool down) {
  switch (virtual_key) {
    case VK_CONTROL:
    case VK_LCONTROL:
    case VK_RCONTROL:
      g_ctrl = down;
      break;
    case VK_MENU:
    case VK_LMENU:
    case VK_RMENU:
      g_alt = down;
      break;
    default:
      break;
  }
}

/// Runs on the thread that installed the hook -- the one pumping the window's
/// messages -- before the key is delivered anywhere. It must return promptly:
/// Windows gives a low-level hook a few hundred milliseconds and silently stops
/// calling one that overruns, for every application.
LRESULT CALLBACK KeyboardHookProc(int code, WPARAM message, LPARAM data) {
  if (code != HC_ACTION) {
    return CallNextHookEx(nullptr, code, message, data);
  }

  const auto* key = reinterpret_cast<const KBDLLHOOKSTRUCT*>(data);
  const bool down = message == WM_KEYDOWN || message == WM_SYSKEYDOWN;
  TrackModifiers(key->vkCode, down);

  // The keyboard belongs to the session only while the session's own window is
  // what the user is looking at. Anywhere else -- another application, the
  // connection centre after the session ends -- Windows must behave normally.
  HWND foreground = GetForegroundWindow();
  if (!IsOurProcess(foreground) || !RdpSession::Instance().IsRunning()) {
    g_last_foreground = nullptr;
    return CallNextHookEx(nullptr, code, message, data);
  }

  // A window that appeared after the capture was turned on gets the same
  // treatment, so that changing the input language with the mouse cannot
  // quietly re-arm the input method behind the user's back.
  if (foreground != g_last_foreground) {
    g_last_foreground = foreground;
    DetachWindowTree(foreground);
  }

  if (!IsWindowsKey(g_alt, g_ctrl, key->vkCode)) {
    // Everything else goes the ordinary way, through the application, which
    // sends it as a scancode. It is delivered exactly once.
    return CallNextHookEx(nullptr, code, message, data);
  }

  // A PS/2 set 1 scancode with the extended bit is what the protocol wants, and
  // it is what Windows hands a low-level hook -- no table needed on this side.
  RdpSession::Instance().QueueKey(static_cast<int32_t>(key->scanCode), down ? 1 : 0,
                                  (key->flags & LLKHF_EXTENDED) != 0 ? 1 : 0);

  // Non-zero: Windows must not also act on it, which is the whole point.
  return 1;
}

/// The module holding the hook procedure.
///
/// GetModuleHandle(nullptr) would be wrong here: inside a DLL it returns the
/// executable's handle, not this library's, and the procedure lives in this
/// library.
HMODULE HookModule() {
  HMODULE module = nullptr;
  GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                         GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                     reinterpret_cast<LPCWSTR>(&KeyboardHookProc), &module);
  return module;
}

}  // namespace
#endif  // _WIN32

bool SetKeyboardCapture(bool enabled) {
#ifndef _WIN32
  (void)enabled;
  return false;
#else
  if (enabled == g_capture_on) {
    return true;
  }

  if (!enabled) {
    g_capture_on = false;
    if (g_hook != nullptr) {
      UnhookWindowsHookEx(g_hook);
      g_hook = nullptr;
    }
    RestoreInputMethod();
    Log("keyboard: capture off; hook removed, input method restored");
    return true;
  }

  // Refuse rather than risk the bad failure mode. A low-level hook whose thread
  // never pumps messages is skipped by the system after a timeout, for every
  // keystroke in every application -- a stalled keyboard everywhere, from a
  // mistake here. A thread that cannot report GUI state has no message queue.
  GUITHREADINFO thread_info = {};
  thread_info.cbSize = sizeof(thread_info);
  if (!GetGUIThreadInfo(GetCurrentThreadId(), &thread_info)) {
    Log("keyboard: the calling thread has no message queue; capture refused");
    return false;
  }

  g_hook = SetWindowsHookExW(WH_KEYBOARD_LL, KeyboardHookProc, HookModule(), 0);
  if (g_hook == nullptr) {
    // Not fatal: the session is still usable, it just keeps the ordinary
    // keyboard path, and the keys Windows keeps for itself stay here.
    Log("keyboard: could not install the hook (error %lu); capture not enabled",
        GetLastError());
    return false;
  }

  g_last_foreground = nullptr;
  g_capture_on = true;
  const int detached = DetachInputMethod();
  Log("keyboard: capture on; input method detached from %d window(s)", detached);
  return true;
#endif
}

}  // namespace rdc
