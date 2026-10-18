// The Linux half of the bridge: an external texture the session's frames are
// drawn through.
//
// This is the counterpart of windows/rdc_bridge_plugin.cpp, and deliberately
// as small. Everything except the frames -- connecting, input, certificates,
// credentials -- crosses the C ABI straight from Dart, so there is no method
// channel and nothing to marshal.

#include "include/rdc_bridge/rdc_bridge_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstdint>
#include <cstring>

#include "rdc_api.h"

namespace {

/// What the presenter answers with when the ring has nothing to give.
///
/// A real buffer rather than a failure: the engine keeps whatever it was last
/// handed, and left to itself that is the previous session's desktop, still on
/// screen for the whole of the next one's connect. One transparent pixel
/// clears the surface -- the widget stretches whatever it is given -- and is
/// the same answer the Windows presenter gives.
const uint8_t kBlankPixel[4] = {0, 0, 0, 0};

FlTextureRegistrar* g_texture_registrar = nullptr;
FlTexture* g_texture = nullptr;

}  // namespace

// G_DECLARE_* macros would normally write these, but the type is private to
// this file: G_DEFINE_TYPE needs the names to exist, and the cast macro is what
// every use of the GObject below is written in terms of.
typedef struct _RdcTexture RdcTexture;
typedef struct _RdcTextureClass RdcTextureClass;

#define RDC_TEXTURE(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), rdc_texture_get_type(), RdcTexture))

struct _RdcTexture {
  FlPixelBufferTexture parent_instance;

  /// Pixels handed to the engine, owned here.
  ///
  /// Linux's pixel-buffer texture has no release callback, so whatever pointer
  /// it is given has to stay valid for as long as the engine wants it. Copying
  /// the frame once per delivery costs a memcpy and removes the question: the
  /// ring's slot can be released immediately, and what the engine holds is
  /// ours to keep.
  uint8_t* buffer;
  size_t capacity;
};

struct _RdcTextureClass {
  FlPixelBufferTextureClass parent_class;
};

G_DEFINE_TYPE(RdcTexture, rdc_texture, fl_pixel_buffer_texture_get_type())

/// Called on the render thread whenever the engine wants the texture's
/// contents. Must produce tightly packed RGBA.
static gboolean CopyPixels(FlPixelBufferTexture* texture, const uint8_t** out_buffer,
                           uint32_t* width, uint32_t* height, GError** error) {
  (void)error;
  RdcTexture* self = RDC_TEXTURE(texture);

  int32_t frame_width = 0;
  int32_t frame_height = 0;
  int32_t stride = 0;
  int32_t release_token = -1;

  const uint8_t* pixels =
      rdc_frame_acquire(&frame_width, &frame_height, &stride, &release_token);
  if (pixels == nullptr) {
    *out_buffer = kBlankPixel;
    *width = 1;
    *height = 1;
    return TRUE;
  }

  const size_t bytes =
      static_cast<size_t>(stride) * static_cast<size_t>(frame_height);
  if (bytes > self->capacity) {
    g_free(self->buffer);
    self->buffer = static_cast<uint8_t*>(g_malloc(bytes));
    self->capacity = bytes;
  }
  std::memcpy(self->buffer, pixels, bytes);
  rdc_frame_release(release_token);

  *out_buffer = self->buffer;
  *width = static_cast<uint32_t>(frame_width);
  *height = static_cast<uint32_t>(frame_height);
  return TRUE;
}

namespace {

/// Raised by the core, from the session thread, when a new frame is published.
void OnFrameReady() {
  if (g_texture_registrar != nullptr && g_texture != nullptr) {
    fl_texture_registrar_mark_texture_frame_available(g_texture_registrar, g_texture);
  }
}

}  // namespace

static void rdc_texture_dispose(GObject* object) {
  RdcTexture* self = RDC_TEXTURE(object);
  g_free(self->buffer);
  self->buffer = nullptr;
  self->capacity = 0;
  G_OBJECT_CLASS(rdc_texture_parent_class)->dispose(object);
}

static void rdc_texture_class_init(RdcTextureClass* klass) {
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels = CopyPixels;
  G_OBJECT_CLASS(klass)->dispose = rdc_texture_dispose;
}

static void rdc_texture_init(RdcTexture* self) {
  self->buffer = nullptr;
  self->capacity = 0;
}

extern "C" FLUTTER_PLUGIN_EXPORT void rdc_bridge_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  FlTextureRegistrar* texture_registrar =
      fl_plugin_registrar_get_texture_registrar(registrar);
  if (texture_registrar == nullptr) {
    // No registrar means no way to show a frame. The session still works; the
    // caller is told so by the -1, which the UI reads as "no texture".
    rdc_set_texture_id(-1);
    return;
  }

  RdcTexture* texture = RDC_TEXTURE(g_object_new(rdc_texture_get_type(), nullptr));
  if (!fl_texture_registrar_register_texture(texture_registrar, FL_TEXTURE(texture))) {
    g_object_unref(texture);
    rdc_set_texture_id(-1);
    return;
  }

  // The registrar holds its own reference from here on.
  g_texture_registrar = texture_registrar;
  g_texture = FL_TEXTURE(texture);
  g_object_unref(texture);

  // Read after registering: the id is assigned by the registrar, and it is what
  // the Flutter side passes to the Texture widget.
  rdc_set_texture_id(fl_texture_get_id(g_texture));
  rdc_set_frame_ready_callback(&OnFrameReady);
}
