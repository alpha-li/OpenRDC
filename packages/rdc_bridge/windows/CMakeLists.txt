# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "rdc_bridge")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed: the Flutter tool links the runner against
# ${plugin}_plugin, and reads ${plugin}_bundled_libraries from here.
set(PLUGIN_NAME "rdc_bridge_plugin")

# === FreeRDP ===============================================================
#
# Flutter's Windows build does not use a vcpkg toolchain, so the package is
# located directly. The root can be overridden per machine with the VCPKG_ROOT
# environment variable or -DVCPKG_ROOT=... ; the default matches this
# checkout's setup.
if(NOT DEFINED VCPKG_ROOT)
  if(DEFINED ENV{VCPKG_ROOT})
    set(VCPKG_ROOT "$ENV{VCPKG_ROOT}")
  else()
    set(VCPKG_ROOT "E:/vcpkg")
  endif()
endif()

set(RDC_VCPKG_TRIPLET "x64-windows" CACHE STRING "vcpkg triplet to link against")
set(RDC_VCPKG_INSTALLED "${VCPKG_ROOT}/installed/${RDC_VCPKG_TRIPLET}")

if(NOT EXISTS "${RDC_VCPKG_INSTALLED}/include/freerdp/freerdp.h")
  message(FATAL_ERROR
    "FreeRDP was not found under ${RDC_VCPKG_INSTALLED}.\n"
    "Install it with:\n"
    "  ${VCPKG_ROOT}/vcpkg.exe install \"freerdp[client]:${RDC_VCPKG_TRIPLET}\"\n"
    "Then re-run the build. Set VCPKG_ROOT or -DVCPKG_ROOT=<path> if vcpkg "
    "lives somewhere else.")
endif()

list(APPEND CMAKE_PREFIX_PATH "${RDC_VCPKG_INSTALLED}")
# find_package needs the config packages, and the runtime DLLs are located
# through these down below.
set(RDC_FREERDP_CONFIG_DIR "${RDC_VCPKG_INSTALLED}/share")
list(APPEND CMAKE_PREFIX_PATH "${RDC_FREERDP_CONFIG_DIR}")

# Three separate packages, each providing exactly one imported target:
# FreeRDP -> freerdp, FreeRDP-Client -> freerdp-client, WinPR -> winpr.
# Omitting one does not fail at configure time; it surfaces as the linker
# asking for a bare "freerdp-client.lib" that does not exist.
find_package(FreeRDP CONFIG REQUIRED)
find_package(FreeRDP-Client CONFIG REQUIRED)
find_package(WinPR CONFIG REQUIRED)

# Linked directly rather than relying on FreeRDP to re-export it: the core calls
# OSSL_PROVIDER_set_default_search_path, and FreeRDP keeps its OpenSSL
# dependency private, so the symbol would otherwise be unresolved.
find_package(OpenSSL CONFIG REQUIRED)

# freerdp-client carries the client-common layer, which is what loads channels.
set(RDC_FREERDP_LIBRARIES freerdp freerdp-client winpr OpenSSL::Crypto)
set(RDC_FREERDP_INCLUDE_DIRS "${RDC_VCPKG_INSTALLED}/include")

# Every runtime dependency, not just the ones directly referenced: Windows
# resolves the import table at load time, so a missing transitive DLL means the
# app fails to start with an unhelpful "code execution cannot proceed" dialog.
# legacy.dll is the OpenSSL legacy provider, and it is not optional: without it
# OpenSSL cannot load md4, NTLM support is compiled out at runtime, and NLA --
# which is on by default on every modern Windows host -- cannot authenticate.
# It fails with a warning in the log rather than an error, so the only symptom
# is connections that never get past "connecting".
set(RDC_FREERDP_DLLS
  "${RDC_VCPKG_INSTALLED}/bin/freerdp3.dll"
  "${RDC_VCPKG_INSTALLED}/bin/freerdp-client3.dll"
  "${RDC_VCPKG_INSTALLED}/bin/winpr3.dll"
  "${RDC_VCPKG_INSTALLED}/bin/libcrypto-3-x64.dll"
  "${RDC_VCPKG_INSTALLED}/bin/libssl-3-x64.dll"
  "${RDC_VCPKG_INSTALLED}/bin/legacy.dll"
  "${RDC_VCPKG_INSTALLED}/bin/cjson.dll"
  "${RDC_VCPKG_INSTALLED}/bin/z.dll"
)

foreach(dll ${RDC_FREERDP_DLLS})
  if(NOT EXISTS "${dll}")
    message(FATAL_ERROR "Expected FreeRDP runtime library is missing: ${dll}")
  endif()
endforeach()

# === Targets ===============================================================

# Builds the portable core, which now links FreeRDP on this platform.
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/rdc_core")

list(APPEND PLUGIN_SOURCES
  "rdc_bridge_plugin.cpp"
  "include/rdc_bridge/rdc_bridge_plugin.h"
)

add_library(${PLUGIN_NAME} SHARED ${PLUGIN_SOURCES})

apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. The one entry point that must stay visible is exported
# explicitly by FLUTTER_PLUGIN_EXPORT in the header.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Lets the generated plugin registrant find <rdc_bridge/rdc_bridge_plugin.h>.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin rdc_bridge)

# Same reason as the core: without /utf-8 MSVC reads the source using the system
# code page, which on a Chinese Windows install is GBK. Any non-ASCII character
# then trips C4819, and the project treats warnings as errors.
if(MSVC)
  target_compile_options(${PLUGIN_NAME} PRIVATE /utf-8)
endif()

# Libraries that must end up next to the application executable.
#
# The core library is opened by Dart by bare name, so it has to sit beside the
# exe, which is also Windows' default DLL search directory. FreeRDP and its
# dependencies go with it.
set(rdc_bridge_bundled_libraries
  "$<TARGET_FILE:rdc_bridge>"
  ${RDC_FREERDP_DLLS}
  PARENT_SCOPE
)
