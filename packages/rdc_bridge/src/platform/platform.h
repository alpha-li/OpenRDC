// What the core asks of the platform it happens to be running on.
//
// Everything here has a portable meaning and a per-platform implementation. The
// core never includes a platform header and never calls a platform API itself:
// it calls these. That is what keeps src/ free of any one platform, and it is
// the same seam that keeps the protocol optional -- a platform which cannot do
// one of these answers so rather than failing to link.
//
// Layout: platform/<name>/ with one file per group below, and platform/null/
// holding the "this platform has no such thing" answers. A new platform is a
// new directory plus a branch in CMakeLists.txt; nothing in src/ moves.

#ifndef RDC_PLATFORM_H_
#define RDC_PLATFORM_H_

#include <cstdint>

namespace rdc {

// --- Window control -------------------------------------------------------
//
// The session draws into a window owned by the application, and the full-screen
// commands are the application's own window's to carry out -- there is no
// windowing protocol involved, which is why they are here and not in the
// session.
//
// A platform with no window system to drive leaves the state at "not full
// screen" and makes the commands do nothing.

/// Tells the platform which window the session is drawn in. Null clears it.
void SetMainWindow(void* native_window_handle);

/// Values match `RDC_WINDOW_*` in rdc_api.h.
void RunWindowCommand(int32_t command);

bool IsWindowFullScreen();

// --- Credential storage ---------------------------------------------------
//
// Passwords go to whatever the platform keeps secrets in, never to a file the
// application writes. A platform with no such store reports
// RDC_ERR_NOT_IMPLEMENTED, and the application asks for the password every
// time instead.
//
// The id is the application's own handle for the credential, not the user name:
// one account can hold several.

int32_t CredentialStore(const char* credential_id, const char* password);

/// Writes the password into `out` and returns its length, or
/// RDC_ERR_NOT_IMPLEMENTED where there is no store. Returns -1 for an unknown
/// id, so "no password saved" and "cannot save passwords" stay distinguishable.
int32_t CredentialLoad(const char* credential_id, char* out, int32_t capacity);

/// The length CredentialLoad would need, or -1 when there is nothing stored.
int32_t CredentialSize(const char* credential_id);

int32_t CredentialDelete(const char* credential_id);

// --- Keyboard capture -----------------------------------------------------
//
// While a session is up, the keys the local system would act on by itself have
// to reach the host instead: its own shell shortcuts, and its own input method,
// which otherwise composes locally and sends the host nothing. Every platform
// has the same problem and answers it differently.
//
// The contract is only this: enabling and disabling is idempotent, and it is
// called from the thread that pumps the application's messages. A capture that
// belongs to a thread which never pumps stalls input for the whole system
// rather than for this process.
//
// Returns false only when the capture could not be installed at all. The
// session still works then, on the ordinary keyboard path.

bool SetKeyboardCapture(bool enabled);

}  // namespace rdc

#endif  // RDC_PLATFORM_H_
