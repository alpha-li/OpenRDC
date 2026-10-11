// The host's mouse cursor, decoded and handed over to be drawn locally.
//
// RDP carries cursors as pictures: an XOR image, an AND mask and a hotspot, with
// no "this is an I-beam" flag anywhere in the protocol. So the only way to show
// what the host is actually showing is to decode those pixels and put them on
// screen. Flutter has no API for a bitmap cursor, which is why the application
// draws it itself rather than asking the platform for one.
//
// The host can also say "use the ordinary arrow" or "hide the pointer". Those
// are states rather than pictures, and are reported as such.

#ifndef RDC_CURSOR_H_
#define RDC_CURSOR_H_

#include <cstdint>

#include "rdc_api.h"

/// Opaque to this header; the implementation includes the FreeRDP headers.
struct rdp_context;
typedef struct rdp_context rdpContext;

namespace rdc {

/// Hooks the pointer callbacks that deliver cursor shapes.
///
/// Called from PostConnect, and the timing is not negotiable: the core installs
/// its own pointer cache over these callbacks immediately *before* PostConnect
/// runs (libfreerdp/core/connection.c), so anything set earlier is replaced and
/// never fires. PostConnect also runs again on a reconnect, which is what keeps
/// the cursor alive across one.
///
/// This is the opposite of the clipboard's rule, where the interface only exists
/// after freerdp_connect has returned -- the two are not interchangeable.
void InstallCursorCapture(rdpContext* context);

/// Forgets the current shape and the decode cache. Safe when nothing was
/// captured.
void ResetCursor();

// --- application side ------------------------------------------------------

/// Fills *out with the current shape. Returns RDC_OK, or RDC_ERR_BAD_ARGUMENT.
int32_t CursorInfo(rdc_cursor_info* out);

/// Copies the current cursor's pixels into `out`, which must hold
/// `capacity` bytes. Returns the number of bytes copied or a negative RDC_ERR_*.
int32_t CursorCopy(uint8_t* out, int32_t capacity);

}  // namespace rdc

#endif  // RDC_CURSOR_H_
