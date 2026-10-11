// Public C ABI for the OpenRDC native bridge.
//
// This header is parsed by ffigen to generate the Dart bindings, so it must
// stay self-contained: no Flutter headers, no C++ types, plain C only.
//
// Layering:
//   src/      portable core  -> rdc_bridge.dll  (opened by Dart via dlopen)
//   windows/  Flutter glue   -> rdc_bridge_plugin.dll (registered by the engine)
//
// The core never includes Flutter headers. It reaches Flutter only through the
// two callbacks below, which the platform glue installs at registration time.

#ifndef RDC_API_H_
#define RDC_API_H_

#include <stdint.h>

#if defined(_WIN32)
#define RDC_EXPORT __declspec(dllexport)
#else
#define RDC_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// ---------------------------------------------------------------------------
// Session state
// ---------------------------------------------------------------------------

enum {
  RDC_STATE_IDLE = 0,
  RDC_STATE_CONNECTING = 1,
  RDC_STATE_AUTHENTICATING = 2,
  RDC_STATE_CONNECTED = 3,
  RDC_STATE_DISCONNECTING = 4,
  RDC_STATE_DISCONNECTED = 5,
  RDC_STATE_FAILED = 6,
};

// Event kinds pushed to Dart. `code` carries an auxiliary value whose meaning
// depends on the kind; `utf8_message` is always human-readable and never null
// (it is an empty string when there is nothing to say).
enum {
  RDC_EVENT_STATE = 1,         // code = one of RDC_STATE_*
  RDC_EVENT_DESKTOP_SIZE = 2,  // code unused; message is "<width>x<height>"
  RDC_EVENT_ERROR = 3,         // code = a negative RDC_ERR_* value
  // A certificate needs a decision before the connection can continue. The
  // session thread is blocked until rdc_respond_certificate is called; details
  // come from rdc_pending_certificate. code is 1 when the certificate differs
  // from the stored one, which is the case worth being careful about.
  RDC_EVENT_CERTIFICATE = 4,
  // Text has arrived from the remote machine's clipboard. code is the length in
  // UTF-16 code units; read it with rdc_clipboard_take.
  RDC_EVENT_CLIPBOARD = 5,
  // The remote machine's mouse pointer changed. code is one of RDC_CURSOR_*;
  // read it with rdc_current_cursor and, for a picture, rdc_cursor_copy.
  RDC_EVENT_CURSOR = 6,
};

// Error codes reported through RDC_EVENT_ERROR.
//
// The sign says which layer produced the failure, which is what lets a caller
// decide whether it has anything useful to say about it:
//
//   negative - this bridge: the session never got going, or something inside
//              the client failed. The application can explain all of these,
//              and they are stable across FreeRDP upgrades.
//   positive - reserved; nothing emits these today. FreeRDP's own error values
//              are deliberately not passed through, because they are a library
//              implementation detail that could be renumbered.
//
// `utf8_message` is always a developer-facing description in English. The
// application is expected to prefer its own wording for codes it recognises.
enum {
  RDC_OK = 0,
  RDC_ERR_NO_TEXTURE_REGISTRAR = -1,
  RDC_ERR_ALREADY_RUNNING = -2,
  RDC_ERR_BAD_ARGUMENT = -3,
  RDC_ERR_NOT_IMPLEMENTED = -4,
  RDC_ERR_NO_CREDENTIALS = -5,
  RDC_ERR_AUTH_FAILED = -6,
  RDC_ERR_NOT_FOUND = -7,
  RDC_ERR_PLATFORM = -8,
  RDC_ERR_SESSION_CONTEXT = -9,
  RDC_ERR_SESSION_START = -10,
  RDC_ERR_EVENT_HANDLES = -11,
  RDC_ERR_EVENT_WAIT = -12,
  RDC_ERR_GDI_INIT = -13,
  RDC_ERR_CONNECT_FAILED = -14,
  RDC_ERR_TLS_FAILED = -15,
  RDC_ERR_PASSWORD_EXPIRED = -16,
};

// Sink for native -> Dart notifications.
//
// Invoked from arbitrary native threads, so the Dart side must register it via
// NativeCallable.listener. Implementations must not block; the caller holds no
// locks but may be the render thread.
//
// LIFETIME: `utf8_message` stays valid until the receiver has read it, which is
// *after* this function returns -- NativeCallable.listener posts the call to
// the receiving isolate rather than running it inline. The core guarantees this
// by copying every message through a per-thread pool before calling, so
// implementations may use string literals, stack buffers or temporaries freely.
typedef void (*rdc_event_fn)(int32_t kind, int32_t code, const char* utf8_message);

// Called when a new frame has been published to the frame ring. The platform
// glue turns this into FlutterDesktopTextureRegistrarMarkExternalTextureFrameAvailable.
typedef void (*rdc_frame_ready_fn)(void);

// ---------------------------------------------------------------------------
// Library metadata and wiring
// ---------------------------------------------------------------------------

// Version of the bridge plus, once FreeRDP is linked in, the FreeRDP version it
// was built against. The returned pointer is static and must not be freed.
RDC_EXPORT const char* rdc_version(void);

// Installs (or clears, with null) the Dart event sink. Safe to call repeatedly.
RDC_EXPORT void rdc_set_event_sink(rdc_event_fn fn);

// Installs (or clears) the frame-ready notification. Called by the platform
// glue with the engine's texture registrar already captured.
RDC_EXPORT void rdc_set_frame_ready_callback(rdc_frame_ready_fn fn);

// Publishes the engine texture id to the core so it can be reported to Dart.
// Pass -1 when no texture is registered.
RDC_EXPORT void rdc_set_texture_id(int64_t texture_id);

// The engine texture id to render into a Flutter `Texture` widget, or -1 when
// the platform has not registered one (unsupported platform, or registration
// failed). Dart polls this once after startup.
RDC_EXPORT int64_t rdc_texture_id(void);

// ---------------------------------------------------------------------------
// Frame ring access
//
// The platform texture presenter calls these from the engine's raster thread.
// `rdc_frame_acquire` hands the caller the most recently published frame and
// pins it; `rdc_frame_release` unpins it. A pinned frame is never written to,
// so the engine can read it without tearing.
// ---------------------------------------------------------------------------

// Returns the published frame's pixels, or null when no frame is available.
// On success writes the geometry into the out parameters and a release token
// that must be passed back to rdc_frame_release.
RDC_EXPORT const uint8_t* rdc_frame_acquire(int32_t* width,
                                            int32_t* height,
                                            int32_t* stride,
                                            int32_t* release_token);

// Unpins a frame previously returned by rdc_frame_acquire.
RDC_EXPORT void rdc_frame_release(int32_t release_token);

// Bytes per pixel of every frame this library produces. Fixed at 4 (RGBA).
RDC_EXPORT int32_t rdc_bytes_per_pixel(void);

// ---------------------------------------------------------------------------
// Real RDP session
// ---------------------------------------------------------------------------

// Everything needed to open a session. Strings are UTF-8 and are copied by
// rdc_connect before it returns, so the caller may free them immediately.
//
// Booleans are int32_t rather than a C bool so the struct layout is not
// compiler-dependent, which matters for a struct crossing an FFI boundary.
typedef struct {
  const char* hostname;
  int32_t port;             // 0 means 3389
  const char* username;     // may be empty; the session then prompts
  const char* password;
  const char* domain;
  int32_t desktop_width;
  int32_t desktop_height;
  int32_t color_depth;      // 32, 24 or 16
  int32_t admin_session;    // connect to the console session
  int32_t ignore_certificate;
  int32_t reconnect_if_dropped;

  // Where remote audio is played. Values match RDC_AUDIO_*.
  int32_t audio_playback;

  // Span the session across every local monitor rather than one desktop.
  int32_t use_multimon;

  int32_t use_gateway;
  const char* gateway_hostname;
  int32_t gateway_port;     // 0 means 443
  const char* gateway_username;
  const char* gateway_password;
  const char* gateway_domain;
  // Skip the gateway for addresses on the local network.
  int32_t gateway_bypass_local;
} rdc_connect_params;

/// Values for rdc_connect_params::audio_playback. These mirror FreeRDP's
/// AUDIO_MODE_* constants, named for what the user chose rather than for where
/// the sound ends up.
enum {
  RDC_AUDIO_ON_THIS_COMPUTER = 0,
  RDC_AUDIO_ON_REMOTE = 1,
  RDC_AUDIO_NEVER = 2,
};

// Starts a session on a background thread and returns immediately with RDC_OK.
// Progress and failure arrive as RDC_EVENT_STATE / RDC_EVENT_ERROR events.
RDC_EXPORT int32_t rdc_connect(const rdc_connect_params* params);

// Queues a local folder to be exposed in the session as a network drive.
//
// Call before rdc_connect, which consumes and clears the list, so a connection
// that fails and is retried does not accumulate duplicates. `name` is what the
// drive is called on the remote machine; an empty name derives one from the
// path.
RDC_EXPORT void rdc_add_redirected_folder(const char* name, const char* path);

// Redirects every drive on this machine instead of specific folders. Also
// consumed by rdc_connect.
RDC_EXPORT void rdc_set_redirect_all_drives(int32_t enabled);

// Asks the remote machine to change its desktop resolution.
//
// Queued and sent from the session thread, and a no-op when no session is
// running. Only honoured by hosts that support display control (Windows 8 and
// Server 2012 onwards); older ones ignore it and keep their original size,
// which the caller detects by never receiving a new RDC_EVENT_DESKTOP_SIZE.
//
// The host is free to clamp: it will refuse sizes outside its own limits, so
// the resulting RDC_EVENT_DESKTOP_SIZE is what the desktop actually became.
RDC_EXPORT void rdc_resize_desktop(int32_t width, int32_t height);

// Requests that the running session stop. Returns immediately; the session
// reports RDC_STATE_DISCONNECTED once it has actually torn down.
RDC_EXPORT void rdc_disconnect(void);

// --- certificate approval --------------------------------------------------

// What to do about a certificate the session is asking about.
enum {
  RDC_CERT_REJECT = 0,
  RDC_CERT_ACCEPT_STORE = 1,  // accept and remember, so it is not asked again
  RDC_CERT_ACCEPT_ONCE = 2,   // accept for this connection only
};

// Details of the certificate the session is waiting on.
//
// Every pointer refers to storage owned by the bridge and stays valid until the
// next certificate event or the end of the session -- long enough to build a
// dialog, not long enough to keep.
typedef struct {
  const char* host;
  int32_t port;
  const char* common_name;
  const char* subject;
  const char* issuer;
  const char* fingerprint;
  // Non-zero when this differs from the certificate previously accepted for
  // this host. That is the case that warrants real scrutiny: a self-signed
  // certificate seen for the first time is a routine decision, while a changed
  // one is what an interception attempt looks like.
  int32_t changed;
  // Non-zero when the name in the certificate does not match the host being
  // connected to. Serious in its own right, and distinct from `changed`: an
  // attacker's certificate is usually both, but a re-addressed server is only
  // this.
  int32_t name_mismatch;
  // The previously accepted fingerprint, or an empty string when unchanged.
  const char* old_fingerprint;
} rdc_certificate_info;

// Fills *out with the pending certificate details. Returns RDC_OK, or
// RDC_ERR_BAD_ARGUMENT when no certificate is pending.
RDC_EXPORT int32_t rdc_pending_certificate(rdc_certificate_info* out);

// Answers the pending certificate question with one of the RDC_CERT_* values,
// unblocking the session thread. Safe to call when nothing is pending, in which
// case it does nothing.
//
// If no answer arrives within a minute the session rejects the certificate and
// fails the connection, so a UI that never answers cannot hang a thread
// forever.
RDC_EXPORT void rdc_respond_certificate(int32_t decision);

// Whether a session is currently running.
RDC_EXPORT int32_t rdc_is_connected(void);

// --- input -----------------------------------------------------------------
//
// Input is queued and dispatched from the session's own thread, because
// FreeRDP's input API has no documented thread-safety guarantee. Every function
// here returns immediately.

enum {
  RDC_MOUSE_MOVE = 0,
  RDC_MOUSE_LEFT_DOWN = 1,
  RDC_MOUSE_LEFT_UP = 2,
  RDC_MOUSE_RIGHT_DOWN = 3,
  RDC_MOUSE_RIGHT_UP = 4,
  RDC_MOUSE_MIDDLE_DOWN = 5,
  RDC_MOUSE_MIDDLE_UP = 6,
  RDC_MOUSE_WHEEL = 7,
};

// `wheel_delta` is in notches, positive for away from the user. It is ignored
// for every action except RDC_MOUSE_WHEEL.
RDC_EXPORT void rdc_mouse(int32_t action, int32_t x, int32_t y, int32_t wheel_delta);

// `scancode` is an RDP scancode, not a virtual key: the mapping happens on the
// Dart side, which is the only place that knows the local keyboard layout.
// `extended` sets KBD_FLAGS_EXTENDED for the grey navigation and keypad keys.
RDC_EXPORT void rdc_key(int32_t scancode, int32_t down, int32_t extended);

// Types a string as UTF-16 code units, bypassing scancode mapping entirely.
// This is the path that works for characters the current layout cannot produce.
RDC_EXPORT void rdc_text(const uint16_t* utf16_code_units, int32_t length);

// Sends the secure attention sequence.
//
// FreeRDP has no API for this and the local OS normally swallows the real key
// combination, so the sequence is synthesised from scancodes.
RDC_EXPORT void rdc_ctrl_alt_del(void);

// --- keyboard capture ------------------------------------------------------

// Takes the keys Windows keeps for itself -- the Windows key, Alt+Tab, Alt+Esc,
// Ctrl+Esc, Alt+F4, Alt+Space, PrintScreen, Ctrl+Space -- and queues them for
// the session instead of letting the local system act on them. While it is on,
// the local input method is detached from this process's windows, so keystrokes
// reach the host unmodified and the host's own input method composes: that is
// what makes typing in a language whose input method lives on the host work at
// all.
//
// Everything else keeps its ordinary path through the application, so no key is
// sent twice and the client's own shortcuts are unaffected. The capture only
// acts while this process's window is in the foreground; the keyboard is the
// local machine's again the moment it is not.
//
// Turning it off restores the input method, which is not optional: the rest of
// the application has text fields, and a window left without its input method
// cannot be typed into in Chinese at all.
//
// MUST be called from the thread that owns the application window and pumps its
// messages -- for this application the Dart UI isolate, which is the platform
// thread. A low-level keyboard hook is delivered to the thread that installed
// it, and one that does not pump would stall the keyboard for the whole system.
RDC_EXPORT void rdc_keyboard_capture(int32_t enabled);

// --- clipboard -------------------------------------------------------------
//
// Only text is redirected. The application owns the local clipboard: it reads
// and writes that itself and tells the bridge what changed, rather than the
// bridge reaching into the OS clipboard from the session thread.

// Announces local clipboard text to the remote machine. The text is copied, so
// the caller may free the buffer on return. A no-op when no session is running.
RDC_EXPORT void rdc_clipboard_set_local(const uint16_t* utf16_code_units, int32_t length);

// Length in UTF-16 code units of the text most recently received from the
// remote machine, or 0 when there is none.
RDC_EXPORT int32_t rdc_clipboard_pending_length(void);

// Copies the pending remote text into `out` and clears it. Returns the number
// of code units copied, or a negative RDC_ERR_* value.
//
// UTF-16 is used rather than UTF-8 because that is what both the protocol and
// the Windows clipboard carry; converting here would only add a lossy step.
RDC_EXPORT int32_t rdc_clipboard_take(uint16_t* out, int32_t capacity);

// --- mouse cursor ----------------------------------------------------------
//
// The remote machine's pointer, for the application to draw. It cannot be a
// platform cursor: RDP sends cursors as pictures rather than as named shapes,
// and Flutter has no API for a bitmap cursor anyway. The application therefore
// hides its own pointer over the desktop and paints this one at the pointer's
// position, offset by the hotspot.
//
// The event only says that the shape changed. Read it back, because by the time
// an event is handled the pointer may already have changed again, and the older
// picture is of no use to anyone.

enum {
  /// The remote machine is asking for the ordinary arrow.
  RDC_CURSOR_DEFAULT = 0,
  /// The remote machine has hidden the pointer, e.g. while playing a video.
  RDC_CURSOR_HIDDEN = 1,
  /// A picture: width, height, hotspot and pixels.
  RDC_CURSOR_IMAGE = 2,
};

/// The current cursor shape. For RDC_CURSOR_IMAGE, byte_length is
/// width * height * 4 and the pixels are RGBA, row by row from the top.
typedef struct {
  int32_t kind;
  int32_t width;
  int32_t height;
  int32_t hotspot_x;
  int32_t hotspot_y;
  int32_t byte_length;
} rdc_cursor_info;

/// Fills *out with the current shape, which is what an RDC_EVENT_CURSOR is
/// reporting. Returns RDC_OK, or RDC_ERR_BAD_ARGUMENT.
RDC_EXPORT int32_t rdc_current_cursor(rdc_cursor_info* out);

/// Copies the current cursor's pixels into `out`, which must have room for
/// rdc_cursor_info.byte_length bytes. Returns the number of bytes copied, or a
/// negative RDC_ERR_* value. A no-op returning 0 when the cursor is not a
/// picture.
RDC_EXPORT int32_t rdc_cursor_copy(uint8_t* out, int32_t capacity);

// ---------------------------------------------------------------------------
// Credential storage
//
// Saved RDP passwords go to the operating system's own secret store -- on
// Windows, Credential Manager. Keeping them here rather than in a file the
// application manages means the operating system's protection applies, they are
// visible and revocable in the user's own credential UI, and the application
// never has to invent a key.
//
// Keys are opaque strings chosen by the caller; the store namespaces them.
// ---------------------------------------------------------------------------

// Stores or replaces the password for `credential_id`. The password is UTF-8.
RDC_EXPORT int32_t rdc_credential_store(const char* credential_id, const char* password);

// Writes the password for `credential_id` into `out` as a NUL-terminated UTF-8
// string. Returns RDC_OK, RDC_ERR_NOT_FOUND when nothing is stored, or
// RDC_ERR_BAD_ARGUMENT when the buffer is too small -- call
// rdc_credential_size first.
RDC_EXPORT int32_t rdc_credential_load(const char* credential_id, char* out, int32_t capacity);

// Bytes needed to hold the password including its terminator, or 0 when
// nothing is stored for this id.
RDC_EXPORT int32_t rdc_credential_size(const char* credential_id);

/// Removes a stored password. Returns RDC_OK even when nothing was stored.
RDC_EXPORT int32_t rdc_credential_delete(const char* credential_id);

// ---------------------------------------------------------------------------
// Window control
//
// The session needs to be able to take over the screen and get out of the way,
// which the Flutter framework cannot do on the desktop. The handle comes from
// the platform glue, which is the only layer that can reach it.
// ---------------------------------------------------------------------------

// Publishes the application's top-level window handle. Called by the platform
// glue at registration. Pass null to clear it.
RDC_EXPORT void rdc_set_main_window(void* native_window_handle);

enum {
  RDC_WINDOW_MINIMIZE = 1,
  // Undoes whichever of the two states the window is in: full screen, in which
  // case the geometry saved on the way in is put back, or minimised/maximised.
  // It is also the "give me my window back" command for a user looking at a
  // full-screen session with no title bar to click.
  RDC_WINDOW_RESTORE = 2,
  RDC_WINDOW_TOGGLE_FULLSCREEN = 3,
  RDC_WINDOW_ENTER_FULLSCREEN = 4,
  RDC_WINDOW_LEAVE_FULLSCREEN = 5,
};

// Performs a window command. No-op on platforms that have no implementation.
//
// "Full screen" here means borderless and covering the monitor the window is
// already on, with the previous geometry saved so it can be restored exactly.
// It is deliberately not the same as maximising: a maximised window keeps its
// title bar, which is the thing a remote desktop session most wants gone.
RDC_EXPORT void rdc_window_command(int32_t command);

// Whether the window is currently in the borderless full-screen state this
// library put it in.
RDC_EXPORT int32_t rdc_window_is_fullscreen(void);

// ---------------------------------------------------------------------------
// Synthetic session
//
// Renders an animated test pattern into the frame ring on a background thread.
// It exists so the ring -> texture -> Flutter path can be exercised without a
// reachable host, and so a broken picture can be attributed to the bridge
// rather than to the network. Mutually exclusive with a real session.
// Returns RDC_OK, or a negative RDC_ERR_* value.
// ---------------------------------------------------------------------------

RDC_EXPORT int32_t rdc_testpattern_start(int32_t width, int32_t height);
RDC_EXPORT void rdc_testpattern_stop(void);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // RDC_API_H_
