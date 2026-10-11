#include "rdc_core.h"

#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace rdc {
namespace {

FrameRing g_ring;
std::atomic<rdc_event_fn> g_event_sink{nullptr};
std::atomic<rdc_frame_ready_fn> g_frame_ready{nullptr};
std::atomic<int64_t> g_texture_id{-1};

// Storage for message strings handed to the event sink.
//
// The sink is delivered through Dart's NativeCallable.listener, which is
// asynchronous: the callback is posted to the receiving isolate and read later,
// so any pointer passed to it must still be valid after the call returns. That
// rules out both stack buffers and the `c_str()` of a temporary, and both have
// caused real bugs here. Every message therefore goes through this pool, which
// is what makes the whole class of mistake impossible rather than merely fixed
// at the call sites that were noticed.
//
// Four slots per thread, rotated, so that events raised back to back do not
// overwrite each other before the receiver drains them.
constexpr int kMessageSlots = 4;
constexpr size_t kMessageSlotSize = 512;

char* NextMessageSlot() {
  thread_local char slots[kMessageSlots][kMessageSlotSize];
  thread_local unsigned next = 0;
  char* buffer = slots[next];
  next = (next + 1) % kMessageSlots;
  buffer[0] = '\0';
  return buffer;
}

/// Copies `source` into storage that outlives the call.
const char* Stabilise(const char* source) {
  if (source == nullptr) {
    return "";
  }
  char* buffer = NextMessageSlot();
  std::snprintf(buffer, kMessageSlotSize, "%s", source);
  return buffer;
}

}  // namespace

const char* TempMessage(const char* format, ...) {
  char* buffer = NextMessageSlot();

  va_list args;
  va_start(args, format);
  std::vsnprintf(buffer, kMessageSlotSize, format, args);
  va_end(args);
  return buffer;
}

FrameRing& Ring() { return g_ring; }

void SetEventSink(rdc_event_fn fn) { g_event_sink.store(fn); }

void SetFrameReadyCallback(rdc_frame_ready_fn fn) { g_frame_ready.store(fn); }

void NotifyFrameReady() {
  if (rdc_frame_ready_fn fn = g_frame_ready.load()) {
    fn();
  }
}

void EmitState(int32_t state, const char* utf8_message) {
  if (rdc_event_fn fn = g_event_sink.load()) {
    fn(RDC_EVENT_STATE, state, Stabilise(utf8_message));
  }
}

void EmitDesktopSize(int32_t width, int32_t height) {
  if (rdc_event_fn fn = g_event_sink.load()) {
    fn(RDC_EVENT_DESKTOP_SIZE, 0, TempMessage("%dx%d", width, height));
  }
}

void EmitError(int32_t code, const char* utf8_message) {
  if (rdc_event_fn fn = g_event_sink.load()) {
    fn(RDC_EVENT_ERROR, code, Stabilise(utf8_message));
  }
}

void EmitRawEvent(int32_t kind, int32_t code, const char* utf8_message) {
  if (rdc_event_fn fn = g_event_sink.load()) {
    fn(kind, code, Stabilise(utf8_message));
  }
}

int64_t TextureId() { return g_texture_id.load(); }

void SetTextureId(int64_t id) { g_texture_id.store(id); }

bool LogEnabled() {
  static const bool enabled = [] {
    // Read once: the variable is a diagnostic switch set before launch, not
    // something that should change under a running session.
    const char* value = std::getenv("OPENRDC_LOG");
    return value != nullptr && value[0] != '\0' && std::strcmp(value, "0") != 0;
  }();
  return enabled;
}

void Log(const char* format, ...) {
  if (!LogEnabled()) {
    return;
  }
  std::fputs("[rdc] ", stderr);

  va_list args;
  va_start(args, format);
  std::vfprintf(stderr, format, args);
  va_end(args);

  std::fputc('\n', stderr);
  std::fflush(stderr);
}

}  // namespace rdc
