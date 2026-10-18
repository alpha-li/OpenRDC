#ifndef FLUTTER_PLUGIN_RDC_BRIDGE_PLUGIN_H_
#define FLUTTER_PLUGIN_RDC_BRIDGE_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

/// Registers the bridge with Flutter.
///
/// There is no method channel: the frames are the whole of the Flutter-facing
/// surface, and everything else crosses the C ABI directly from Dart. So this
/// registers one external texture and nothing more.
FLUTTER_PLUGIN_EXPORT void rdc_bridge_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_RDC_BRIDGE_PLUGIN_H_
