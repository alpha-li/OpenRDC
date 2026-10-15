// Platform glue between the Flutter engine and the portable core in ../src.
//
// The core deliberately knows nothing about Flutter, so this file is where the
// engine's texture registrar is captured, a pixel-buffer texture is registered
// against the core's frame ring, and core frame notifications are turned into
// MarkExternalTextureFrameAvailable calls.
//
// This uses the plain C texture API rather than the C++ wrapper: the C entry
// points are explicitly documented as callable from any thread, which is what
// the core's producer thread needs.

#include "include/rdc_bridge/rdc_bridge_plugin.h"

#include <windows.h>

#include <flutter_plugin_registrar.h>
#include <flutter_texture_registrar.h>
#include <string>

#include "../src/rdc_api.h"

// Note: the OpenSSL provider path is configured by the core, in
// ConfigureOpenSslProviderPath (../src/rdc_session.cpp). It cannot be done here:
// this DLL's import table pulls libcrypto in, so OpenSSL is already initialised
// by the time anything in this file runs.
//
// The same applies to the main window: the core resolves it on demand, because
// at registration time the runner has not created it yet.

namespace {

FlutterDesktopTextureRegistrarRef g_texture_registrar = nullptr;
int64_t g_texture_id = -1;

// Invoked by the engine on its raster thread.
//
// The engine copies the buffer synchronously before returning from this
// callback and calls release_callback once it is done, so returning the address
// of a function-local static descriptor is safe: the descriptor itself is only
// read during the call. The pixel data behind it is pinned in the frame ring
// until release_callback fires, which is what keeps the producer from
// overwriting a frame mid-upload.
const FlutterDesktopPixelBuffer* CopyPixelBuffer(size_t /*width*/, size_t /*height*/,
                                                void* /*user_data*/) {
  static FlutterDesktopPixelBuffer descriptor;

  int32_t width = 0;
  int32_t height = 0;
  int32_t stride = 0;
  int32_t release_token = -1;

  const uint8_t* pixels = rdc_frame_acquire(&width, &height, &stride, &release_token);
  if (pixels == nullptr) {
    // Nothing has been produced for this session yet. Returning null would make
    // the engine go on showing whatever it last had -- and on the second
    // connection of a run that is the desktop of the machine connected to a
    // moment ago, sitting there for the whole of the new one's connect. One
    // transparent pixel instead clears the surface: the widget stretches
    // whatever it is handed, so a single pixel covers the whole of it.
    static const uint8_t kBlank[4] = {0, 0, 0, 0};
    descriptor.buffer = kBlank;
    descriptor.width = 1;
    descriptor.height = 1;
    descriptor.release_context = nullptr;
    descriptor.release_callback = nullptr;
    return &descriptor;
  }

  descriptor.buffer = pixels;
  descriptor.width = static_cast<size_t>(width);
  descriptor.height = static_cast<size_t>(height);
  descriptor.release_context = reinterpret_cast<void*>(static_cast<intptr_t>(release_token));
  descriptor.release_callback = [](void* context) {
    rdc_frame_release(static_cast<int32_t>(reinterpret_cast<intptr_t>(context)));
  };
  return &descriptor;
}

void OnFrameReady() {
  if (g_texture_registrar != nullptr && g_texture_id >= 0) {
    FlutterDesktopTextureRegistrarMarkExternalTextureFrameAvailable(g_texture_registrar,
                                                                   g_texture_id);
  }
}

}  // namespace

extern "C" FLUTTER_PLUGIN_EXPORT void RdcBridgePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {

  g_texture_registrar = FlutterDesktopRegistrarGetTextureRegistrar(registrar);
  if (g_texture_registrar == nullptr) {
    rdc_set_texture_id(-1);
    return;
  }

  FlutterDesktopTextureInfo info = {};
  info.type = kFlutterDesktopPixelBufferTexture;
  info.pixel_buffer_config.callback = &CopyPixelBuffer;
  info.pixel_buffer_config.user_data = nullptr;

  g_texture_id = FlutterDesktopTextureRegistrarRegisterExternalTexture(g_texture_registrar, &info);

  // Hand the id to the core so Dart can pick it up, and wire the frame
  // notification in the other direction.
  rdc_set_texture_id(g_texture_id);
  rdc_set_frame_ready_callback(&OnFrameReady);
}
