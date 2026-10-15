# The portable core of the bridge. Built as a standalone shared library because
# Dart opens it directly by name with DynamicLibrary.open, and because keeping
# it free of Flutter dependencies is what makes the other platforms a matter of
# adding a glue layer rather than rewriting this one.
#
# Nothing here may include a Flutter header.

cmake_minimum_required(VERSION 3.14)

project(rdc_bridge_library VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The portable core. Nothing here may call a platform API or include a platform
# header: what it asks of the platform is declared in platform/platform.h and
# implemented per platform below.
set(RDC_CORE_SOURCES
  "rdc_api.cpp"
  "rdc_api.h"
  "rdc_clipboard.h"
  "rdc_core.cpp"
  "rdc_core.h"
  "rdc_cursor.h"
  "rdc_frame_ring.cpp"
  "rdc_frame_ring.h"
  "rdc_session.h"
  "rdc_testpattern.cpp"
  "rdc_testpattern.h"
  "platform/platform.h"
)

# --- Which platform answers platform.h -------------------------------------
#
# A separate axis from the protocol below, and deliberately not folded into it.
# Window control, credential storage and keyboard capture have nothing to do
# with whether FreeRDP is present -- the keyboard one in particular was chosen
# by it before, which was wrong twice over: it is a platform implementation, and
# it does not use FreeRDP at all.
#
# platform/null/ answers every one of them where a platform has not been
# implemented, which is what keeps the ABI complete and the library loadable
# before there is anything behind it.
if(WIN32)
  list(APPEND RDC_CORE_SOURCES
    "platform/windows/keyboard.cpp"
    "platform/windows/window.cpp"
    "platform/windows/credential.cpp"
  )
else()
  list(APPEND RDC_CORE_SOURCES
    "platform/null/keyboard.cpp"
    "platform/null/window.cpp"
    "platform/null/credential.cpp"
  )
endif()

# --- Whether the protocol below is real ------------------------------------
#
# The real implementation needs FreeRDP. Where it is unavailable the stub keeps
# the full ABI exported so the library still loads and callers get a clear
# "built without protocol support" error instead of a link failure.
if(RDC_FREERDP_LIBRARIES)
  list(APPEND RDC_CORE_SOURCES
    "rdc_clipboard.cpp"
    "rdc_cursor.cpp"
    "rdc_session.cpp"
  )
else()
  list(APPEND RDC_CORE_SOURCES
    "rdc_clipboard_stub.cpp"
    "rdc_cursor_stub.cpp"
    "rdc_session_stub.cpp"
  )
endif()

add_library(rdc_bridge SHARED ${RDC_CORE_SOURCES})

set_target_properties(rdc_bridge PROPERTIES
  PUBLIC_HEADER rdc_api.h
  OUTPUT_NAME "rdc_bridge"
  # The C entry points are the library's entire reason to exist, so they must
  # not be hidden. On Windows rdc_api.h applies dllexport explicitly.
  CXX_VISIBILITY_PRESET default
)

target_compile_definitions(rdc_bridge PUBLIC DART_SHARED_LIB)

if (MSVC)
  # /utf-8 is not optional here. Without it MSVC decodes the source using the
  # system code page, which on a Chinese Windows install is GBK: the UTF-8
  # Chinese literals in the session code then fail to parse, and any that do
  # survive are mojibake at runtime when they reach the UI.
  target_compile_options(rdc_bridge PRIVATE /W4 /permissive- /utf-8)
  target_compile_definitions(rdc_bridge PRIVATE _CRT_SECURE_NO_WARNINGS NOMINMAX WIN32_LEAN_AND_MEAN)
else()
  target_compile_options(rdc_bridge PRIVATE -Wall -Wextra)
endif()

find_package(Threads REQUIRED)
target_link_libraries(rdc_bridge PRIVATE Threads::Threads)

if(WIN32)
  # The keyboard capture detaches the local input method with ImmAssociateContext
  # (rdc_keyboard.cpp). imm32 is not among the libraries MSVC links by default,
  # unlike user32, which is why the window code next door needs nothing here.
  target_link_libraries(rdc_bridge PRIVATE imm32)
endif()

# FreeRDP is supplied by the platform glue layer (see ../windows/CMakeLists.txt).
# When it is absent the library still builds and exports the full ABI; the
# session entry points then report that they were built without protocol
# support, rather than the platform failing to compile at all.
if(RDC_FREERDP_LIBRARIES)
  target_compile_definitions(rdc_bridge PRIVATE RDC_WITH_FREERDP=1)
  target_link_libraries(rdc_bridge PRIVATE ${RDC_FREERDP_LIBRARIES})
  if(RDC_FREERDP_INCLUDE_DIRS)
    target_include_directories(rdc_bridge PRIVATE ${RDC_FREERDP_INCLUDE_DIRS})
  endif()
endif()

# Include this directory so the glue layer can reach rdc_api.h as "rdc_api.h".
target_include_directories(rdc_bridge PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(rdc_bridge PRIVATE "-Wl,-z,max-page-size=16384")
endif()
