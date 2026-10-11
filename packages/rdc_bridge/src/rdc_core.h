// Process-wide state shared by the C ABI entry points and whichever session
// happens to be running. One RDP session per process for now, which matches how
// the app is used (one window, one connection); the state below would move into
// a session object if that ever changes.

#ifndef RDC_CORE_H_
#define RDC_CORE_H_

#include <atomic>
#include <cstdint>

#include "rdc_api.h"
#include "rdc_frame_ring.h"

namespace rdc {

FrameRing& Ring();

// The sinks are installed by Dart (event sink) and by the platform glue
// (frame-ready callback) and are read from session threads, hence atomics.
// They may legitimately be null before startup wiring completes, so every
// emitter must tolerate that.
void SetEventSink(rdc_event_fn fn);
void SetFrameReadyCallback(rdc_frame_ready_fn fn);

// Notifies the engine that Ring() holds a new frame. No-op when unwired.
void NotifyFrameReady();

void EmitState(int32_t state, const char* utf8_message);
void EmitDesktopSize(int32_t width, int32_t height);
void EmitError(int32_t code, const char* utf8_message);

/// Raises an event the typed emitters above do not cover.
void EmitRawEvent(int32_t kind, int32_t code, const char* utf8_message);

/// Formats into storage that stays valid after the current call returns.
///
/// Use this for any message that will be handed to the event sink. The sink is
/// delivered asynchronously, so a stack buffer or the `c_str()` of a temporary
/// is a use-after-free by the time the receiver reads it -- both have caused
/// real bugs here. There is a small rotating per-thread pool, so a few messages
/// can be in flight before the receiver drains them.
const char* TempMessage(const char* format, ...);

int64_t TextureId();
void SetTextureId(int64_t id);

// Window control, implemented in rdc_window.cpp. On platforms with no
// implementation the state is simply always "not full screen" and the commands
// do nothing.
void SetMainWindow(void* native_window_handle);
void RunWindowCommand(int32_t command);
bool IsWindowFullScreen();

// Credential storage, implemented in rdc_credential.cpp. On platforms without
// a native secret store these report RDC_ERR_NOT_IMPLEMENTED.
int32_t CredentialStore(const char* credential_id, const char* password);
int32_t CredentialLoad(const char* credential_id, char* out, int32_t capacity);
int32_t CredentialSize(const char* credential_id);
int32_t CredentialDelete(const char* credential_id);

/// Whether diagnostic logging is on, i.e. the OPENRDC_LOG environment variable
/// was set when the process started.
bool LogEnabled();

/// Writes a diagnostic line to stderr when logging is enabled.
///
/// Deliberately not FreeRDP's WLog: this reports the bridge's own progress, and
/// the two need to be separable when working out whether a failure is ours or
/// the protocol stack's.
void Log(const char* format, ...);

}  // namespace rdc

#endif  // RDC_CORE_H_
