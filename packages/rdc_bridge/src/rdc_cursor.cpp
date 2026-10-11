#include "rdc_cursor.h"

#include <freerdp/codec/color.h>
#include <freerdp/freerdp.h>
#include <freerdp/gdi/gdi.h>
#include <freerdp/pointer.h>

#include <cstring>
#include <map>
#include <mutex>
#include <vector>

#include "rdc_core.h"

namespace rdc {
namespace {

/// The largest pointer Windows will send. Anything beyond this is a malformed
/// or hostile PDU, and allocating on the strength of a length field alone is
/// how a remote machine gets to decide how much memory this one uses.
constexpr int kMaxCursorSide = 512;

/// A decoded cursor: pixels, size, and the point in the picture that sits under
/// the pointer.
struct CursorImage {
  int32_t width = 0;
  int32_t height = 0;
  int32_t hotspot_x = 0;
  int32_t hotspot_y = 0;
  std::vector<uint8_t> pixels;

  int32_t ByteLength() const {
    return static_cast<int32_t>(pixels.size());
  }
};

std::mutex g_mutex;
int32_t g_kind = RDC_CURSOR_DEFAULT;
CursorImage g_current;

/// Decoded cursors by the index the server gave them, for the PDUs that only
/// refer to one it sent earlier.
// Keyed by the index the server gave the picture. The colour and large
// pointer PDUs disagree about its width -- UINT16 against UINT32 -- so the key
// is the wider of the two and the narrower one promotes.
std::map<uint32_t, CursorImage> g_cache;

/// Publishes a new shape, and tells the application it changed.
///
/// The event carries no picture: it says "the pointer is different now", and
/// the application reads the shape back. By the time an event is handled the
/// pointer may already have changed again, so sending the picture along with it
/// would only invite the reader to draw a stale one.
void Publish(int32_t kind, const CursorImage& image) {
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_kind = kind;
    g_current = kind == RDC_CURSOR_IMAGE ? image : CursorImage();
  }
  EmitRawEvent(RDC_EVENT_CURSOR, kind, nullptr);
}

/// Turns one pointer PDU's masks into RGBA pixels.
///
/// Must happen inside the callback that received them: the mask buffers belong
/// to the update PDU and are freed as soon as it returns.
bool Decode(rdpContext* context, int32_t width, int32_t height, int32_t hotspot_x,
            int32_t hotspot_y, const BYTE* xor_mask, UINT32 xor_length, const BYTE* and_mask,
            UINT32 and_length, UINT32 xor_bpp, CursorImage* out) {
  if (width <= 0 || height <= 0 || width > kMaxCursorSide || height > kMaxCursorSide) {
    Log("cursor: refused a %dx%d pointer", static_cast<int>(width), static_cast<int>(height));
    return false;
  }
  if (xor_mask == nullptr) {
    return false;
  }

  out->width = width;
  out->height = height;
  out->hotspot_x = hotspot_x;
  out->hotspot_y = hotspot_y;
  // The colour cursor PDUs carry 24bpp masks; the newer ones say so themselves.
  out->pixels.assign(static_cast<size_t>(width) * static_cast<size_t>(height) * 4, 0);

  /* RGBA, the same format the frame ring hands to the renderer, so a cursor and
   * the desktop behind it cannot disagree about byte order. The palette is only
   * consulted for the ancient 8bpp pointers, which is why it may be null. */
  gdiPalette* palette = context != nullptr && context->gdi != nullptr ? &context->gdi->palette
                                                                     : nullptr;
  if (!freerdp_image_copy_from_pointer_data(out->pixels.data(), PIXEL_FORMAT_RGBA32, 0, 0, 0,
                                            static_cast<UINT32>(width),
                                            static_cast<UINT32>(height), xor_mask, xor_length,
                                            and_mask, and_length, xor_bpp, palette)) {
    Log("cursor: could not decode a %dx%d pointer at %u bpp", static_cast<int>(width),
        static_cast<int>(height), static_cast<unsigned>(xor_bpp));
    return false;
  }
  return true;
}

/// Files a decoded picture under the index the server will refer to it by, and
/// makes it the one on screen.
void Put(uint32_t cache_index, CursorImage image) {
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_kind = RDC_CURSOR_IMAGE;
    g_current = image;
    g_cache[cache_index] = std::move(image);
  }
  EmitRawEvent(RDC_EVENT_CURSOR, RDC_CURSOR_IMAGE, nullptr);
}

// ---------------------------------------------------------------------------
// The callbacks. All run on the session thread, inside the update dispatch.
// ---------------------------------------------------------------------------

BOOL OnPointerSystem(rdpContext* /*context*/, const POINTER_SYSTEM_UPDATE* update) {
  if (update == nullptr) {
    return FALSE;
  }
  Publish(update->type == SYSPTR_NULL ? RDC_CURSOR_HIDDEN : RDC_CURSOR_DEFAULT, CursorImage());
  return TRUE;
}

BOOL OnPointerNew(rdpContext* context, const POINTER_NEW_UPDATE* update) {
  if (update == nullptr) {
    return FALSE;
  }
  const POINTER_COLOR_UPDATE* attr = &update->colorPtrAttr;
  CursorImage image;
  if (!Decode(context, attr->width, attr->height, attr->hotSpotX, attr->hotSpotY,
              attr->xorMaskData, attr->lengthXorMask, attr->andMaskData, attr->lengthAndMask,
              update->xorBpp, &image)) {
    return FALSE;
  }
  Put(attr->cacheIndex, std::move(image));
  return TRUE;
}

BOOL OnPointerColor(rdpContext* context, const POINTER_COLOR_UPDATE* update) {
  if (update == nullptr) {
    return FALSE;
  }
  CursorImage image;
  // This PDU has no xorBpp field; the protocol fixes it at 24bpp. FreeRDP's own
  // pointer cache hardcodes the same value.
  if (!Decode(context, update->width, update->height, update->hotSpotX, update->hotSpotY,
              update->xorMaskData, update->lengthXorMask, update->andMaskData,
              update->lengthAndMask, 24, &image)) {
    return FALSE;
  }
  Put(update->cacheIndex, std::move(image));
  return TRUE;
}

BOOL OnPointerLarge(rdpContext* context, const POINTER_LARGE_UPDATE* update) {
  if (update == nullptr) {
    return FALSE;
  }
  CursorImage image;
  if (!Decode(context, update->width, update->height, update->hotSpotX, update->hotSpotY,
              update->xorMaskData, update->lengthXorMask, update->andMaskData,
              update->lengthAndMask, update->xorBpp, &image)) {
    return FALSE;
  }
  Put(update->cacheIndex, std::move(image));
  return TRUE;
}

BOOL OnPointerCached(rdpContext* /*context*/, const POINTER_CACHED_UPDATE* update) {
  if (update == nullptr) {
    return FALSE;
  }

  {
    std::lock_guard<std::mutex> lock(g_mutex);
    const auto entry = g_cache.find(update->cacheIndex);
    if (entry == g_cache.end()) {
      // The server is referring to a pointer it never sent, or sent before this
      // session. Nothing useful can be drawn; the previous shape stays.
      Log("cursor: no cached pointer %u", static_cast<unsigned>(update->cacheIndex));
      return TRUE;
    }
    g_kind = RDC_CURSOR_IMAGE;
    g_current = entry->second;
  }

  EmitRawEvent(RDC_EVENT_CURSOR, RDC_CURSOR_IMAGE, nullptr);
  return TRUE;
}

}  // namespace

void InstallCursorCapture(rdpContext* context) {
  if (context == nullptr || context->update == nullptr || context->update->pointer == nullptr) {
    return;
  }

  rdpPointerUpdate* pointer = context->update->pointer;
  pointer->PointerSystem = OnPointerSystem;
  pointer->PointerNew = OnPointerNew;
  pointer->PointerColor = OnPointerColor;
  pointer->PointerLarge = OnPointerLarge;
  pointer->PointerCached = OnPointerCached;

  Log("cursor: pointer callbacks installed");
}

void ResetCursor() {
  std::lock_guard<std::mutex> lock(g_mutex);
  g_kind = RDC_CURSOR_DEFAULT;
  g_current = CursorImage();
  g_cache.clear();
}

int32_t CursorInfo(rdc_cursor_info* out) {
  if (out == nullptr) {
    return RDC_ERR_BAD_ARGUMENT;
  }

  std::lock_guard<std::mutex> lock(g_mutex);
  out->kind = g_kind;
  out->width = g_current.width;
  out->height = g_current.height;
  out->hotspot_x = g_current.hotspot_x;
  out->hotspot_y = g_current.hotspot_y;
  out->byte_length = g_kind == RDC_CURSOR_IMAGE ? g_current.ByteLength() : 0;
  return RDC_OK;
}

int32_t CursorCopy(uint8_t* out, int32_t capacity) {
  if (out == nullptr || capacity <= 0) {
    return RDC_ERR_BAD_ARGUMENT;
  }

  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_kind != RDC_CURSOR_IMAGE || g_current.pixels.empty()) {
    return 0;
  }

  const size_t length = g_current.pixels.size();
  if (static_cast<size_t>(capacity) < length) {
    return RDC_ERR_BAD_ARGUMENT;
  }
  std::memcpy(out, g_current.pixels.data(), length);
  return static_cast<int32_t>(length);
}

}  // namespace rdc
