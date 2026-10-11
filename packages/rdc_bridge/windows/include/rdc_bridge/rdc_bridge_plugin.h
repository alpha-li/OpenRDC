// Registration entry point for the OpenRDC native bridge.
//
// The Flutter tool generates a call to RdcBridgePluginRegisterWithRegistrar()
// in windows/flutter/generated_plugin_registrant.cc. That function name and
// this file's path are both derived from the `pluginClass: RdcBridgePlugin`
// entry in pubspec.yaml, so neither can be renamed independently of it.

#ifndef FLUTTER_PLUGIN_RDC_BRIDGE_PLUGIN_H_
#define FLUTTER_PLUGIN_RDC_BRIDGE_PLUGIN_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void RdcBridgePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}
#endif

#endif  // FLUTTER_PLUGIN_RDC_BRIDGE_PLUGIN_H_
