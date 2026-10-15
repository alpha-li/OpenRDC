// Implementation of the public C ABI declared in rdc_api.h.

#include "rdc_api.h"

#include <cstdio>
#include <cstring>
#include <mutex>

#include "rdc_core.h"
#include "rdc_clipboard.h"
#include "rdc_cursor.h"
#include "platform/platform.h"
#include "rdc_session.h"
#include "rdc_testpattern.h"

namespace {

// One session per process for now; see rdc_core.h.
rdc::TestPatternSession g_test_pattern;
std::mutex g_version_mutex;

// Built lazily so the FreeRDP version can be appended once the real client is
// linked in, without changing the ABI.
const char* BuildVersionString() {
  static char buffer[256] = {};
  std::lock_guard<std::mutex> lock(g_version_mutex);
  if (buffer[0] == '\0') {
    std::snprintf(buffer, sizeof(buffer),
                  "OpenRDC bridge 0.1.0 (%d bytes/pixel, %d frame slots)", rdc_bytes_per_pixel(),
                  rdc::FrameRing::kSlotCount);
  }
  return buffer;
}

}  // namespace

extern "C" {

const char* rdc_version(void) { return BuildVersionString(); }

void rdc_set_event_sink(rdc_event_fn fn) { rdc::SetEventSink(fn); }

void rdc_set_frame_ready_callback(rdc_frame_ready_fn fn) { rdc::SetFrameReadyCallback(fn); }

void rdc_set_texture_id(int64_t texture_id) { rdc::SetTextureId(texture_id); }

int64_t rdc_texture_id(void) { return rdc::TextureId(); }

const uint8_t* rdc_frame_acquire(int32_t* width, int32_t* height, int32_t* stride,
                                 int32_t* release_token) {
  return rdc::Ring().Acquire(width, height, stride, release_token);
}

void rdc_frame_release(int32_t release_token) { rdc::Ring().Release(release_token); }

int32_t rdc_bytes_per_pixel(void) { return rdc::FrameRing::kBytesPerPixel; }

int32_t rdc_connect(const rdc_connect_params* params) {
  if (params == nullptr) {
    return RDC_ERR_BAD_ARGUMENT;
  }
  if (g_test_pattern.running()) {
    return RDC_ERR_ALREADY_RUNNING;
  }
  return rdc::RdpSession::Instance().Connect(*params);
}

void rdc_disconnect(void) { rdc::RdpSession::Instance().Disconnect(); }

int32_t rdc_is_connected(void) { return rdc::RdpSession::Instance().IsRunning() ? 1 : 0; }

void rdc_add_redirected_folder(const char* name, const char* path) {
  if (name == nullptr || path == nullptr) {
    return;
  }
  rdc::RdpSession::Instance().AddRedirectedFolder(name, path);
}

void rdc_set_redirect_all_drives(int32_t enabled) {
  rdc::RdpSession::Instance().SetRedirectAllDrives(enabled != 0);
}

void rdc_resize_desktop(int32_t width, int32_t height) {
  rdc::RdpSession::Instance().QueueResize(width, height);
}

int32_t rdc_credential_store(const char* credential_id, const char* password) {
  return rdc::CredentialStore(credential_id, password);
}

int32_t rdc_credential_load(const char* credential_id, char* out, int32_t capacity) {
  return rdc::CredentialLoad(credential_id, out, capacity);
}

int32_t rdc_credential_size(const char* credential_id) {
  return rdc::CredentialSize(credential_id);
}

int32_t rdc_credential_delete(const char* credential_id) {
  return rdc::CredentialDelete(credential_id);
}

int32_t rdc_pending_certificate(rdc_certificate_info* out) {
  return rdc::RdpSession::Instance().GetPendingCertificate(out);
}

void rdc_respond_certificate(int32_t decision) {
  rdc::RdpSession::Instance().RespondToCertificate(decision);
}

void rdc_mouse(int32_t action, int32_t x, int32_t y, int32_t wheel_delta) {
  rdc::RdpSession::Instance().QueueMouse(action, x, y, wheel_delta);
}

void rdc_key(int32_t scancode, int32_t down, int32_t extended) {
  rdc::RdpSession::Instance().QueueKey(scancode, down, extended);
}

void rdc_text(const uint16_t* utf16_code_units, int32_t length) {
  rdc::RdpSession::Instance().QueueText(utf16_code_units, length);
}

void rdc_ctrl_alt_del(void) { rdc::RdpSession::Instance().QueueCtrlAltDel(); }

void rdc_keyboard_capture(int32_t enabled) { rdc::SetKeyboardCapture(enabled != 0); }

void rdc_set_main_window(void* native_window_handle) {
  rdc::SetMainWindow(native_window_handle);
}

void rdc_window_command(int32_t command) { rdc::RunWindowCommand(command); }

int32_t rdc_window_is_fullscreen(void) { return rdc::IsWindowFullScreen() ? 1 : 0; }

void rdc_clipboard_set_local(const uint16_t* utf16_code_units, int32_t length) {
  rdc::ClipboardBridge::Instance().SetLocalText(utf16_code_units, length);
}

int32_t rdc_clipboard_pending_length(void) {
  return rdc::ClipboardBridge::Instance().PendingLength();
}

int32_t rdc_clipboard_take(uint16_t* out, int32_t capacity) {
  return rdc::ClipboardBridge::Instance().TakePending(out, capacity);
}

int32_t rdc_current_cursor(rdc_cursor_info* out) { return rdc::CursorInfo(out); }

int32_t rdc_cursor_copy(uint8_t* out, int32_t capacity) { return rdc::CursorCopy(out, capacity); }

int32_t rdc_testpattern_start(int32_t width, int32_t height) {
  // The synthetic producer writes into the same ring a real session would, so
  // the two cannot coexist.
  if (rdc::RdpSession::Instance().IsRunning()) {
    return RDC_ERR_ALREADY_RUNNING;
  }
  return g_test_pattern.Start(width, height);
}

void rdc_testpattern_stop(void) { g_test_pattern.Stop(); }

}  // extern "C"
