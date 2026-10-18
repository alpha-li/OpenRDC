//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <rdc_bridge/rdc_bridge_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) rdc_bridge_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "RdcBridgePlugin");
  rdc_bridge_plugin_register_with_registrar(rdc_bridge_registrar);
}
