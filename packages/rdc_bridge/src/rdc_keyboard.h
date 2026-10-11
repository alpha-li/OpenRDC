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
//   * A low-level keyboard hook that takes the keys in the table inside
//     rdc_keyboard.cpp and queues them for the session instead of letting
//     Windows act on them.
//   * The local input method detached from this process's windows, so keys
//     arrive as ordinary key messages and the *host's* input method does the
//     composing. That is what keeps the remote keyboard indicator, the remote
//     candidate window and what actually appears on the remote screen
//     consistent with one another.
//
// Only keys Windows would act on itself are taken. Everything else keeps
// flowing through the application (Flutter -> Dart -> scancodes), so no key is
// ever delivered twice and the client's own shortcuts keep working.

#ifndef RDC_KEYBOARD_H_
#define RDC_KEYBOARD_H_

namespace rdc {

/// Installs or removes the capture. Idempotent.
///
/// MUST be called from the thread that owns the application's window and pumps
/// its messages -- here the Dart UI isolate, which on Windows is the platform
/// thread. A low-level keyboard hook is delivered to the thread that installed
/// it, and a thread that never pumps messages would stall the keyboard for the
/// whole system instead of just this process.
///
/// Returns false only when the hook could not be installed at all; the session
/// still works then, it simply keeps the ordinary keyboard path.
bool SetKeyboardCapture(bool enabled);

}  // namespace rdc

#endif  // RDC_KEYBOARD_H_
