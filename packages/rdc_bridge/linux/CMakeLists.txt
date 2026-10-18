# The Flutter tooling requires CMake 3.10 or later; the plugin template pins
# that version so the plugin keeps building for older toolchains.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "rdc_bridge")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must not
# be changed: the Flutter tool links the runner against ${plugin}_plugin.
set(PLUGIN_NAME "rdc_bridge_plugin")

# === FreeRDP ===============================================================
#
# On Linux FreeRDP is a distribution library, and pkg-config is how a
# distribution says where it is -- unlike Windows, where the package comes from
# vcpkg and this project carries its own copy. Taking the system's copy is also
# what keeps the ABI consistent with everything else on the machine.
find_package(PkgConfig REQUIRED)
pkg_check_modules(FREERDP REQUIRED IMPORTED_TARGET freerdp3 freerdp-client3 winpr3)

# Linked directly because the core calls OSSL_PROVIDER_set_default_search_path
# and FreeRDP keeps its OpenSSL dependency private.
find_package(OpenSSL REQUIRED)

set(RDC_FREERDP_LIBRARIES PkgConfig::FREERDP OpenSSL::Crypto)
set(RDC_FREERDP_INCLUDE_DIRS ${FREERDP_INCLUDE_DIRS})

# === Targets ===============================================================

# The portable core, linked against the system FreeRDP.
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/rdc_core")

list(APPEND PLUGIN_SOURCES
  "rdc_bridge_plugin.cc"
  "include/rdc_bridge/rdc_bridge_plugin.h"
)

add_library(${PLUGIN_NAME} SHARED ${PLUGIN_SOURCES})

apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. The one entry point that must stay visible is exported
# explicitly by FLUTTER_PLUGIN_EXPORT in the header.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  # The core is installed beside the plugin, in the bundle's lib/, so that is
  # where the installed plugin has to look for it. Left to itself CMake keeps
  # the build tree's absolute path here, which resolves on the machine that
  # built it and nowhere else.
  INSTALL_RPATH "$ORIGIN"
  # The bundle copies the plugin as a file rather than installing it as a
  # target, and a file copy does not rewrite the run path -- so the built
  # artifact has to carry the right one already.
  BUILD_WITH_INSTALL_RPATH TRUE)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Lets the generated plugin registrant find <rdc_bridge/rdc_bridge_plugin.h>.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${PLUGIN_NAME} PRIVATE rdc_bridge)

# Libraries that must end up next to the application executable.
#
# The core is opened by Dart by bare name, so it has to sit beside the runner,
# which is also the loader's default search directory. FreeRDP itself is left
# to the system: it is a distribution package here, and bundling a second copy
# would be the thing that lets the two drift apart.
set(rdc_bridge_bundled_libraries
  "$<TARGET_FILE:rdc_bridge>"
  PARENT_SCOPE
)
