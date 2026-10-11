// Fallback implementation of ClipboardBridge for platforms built without
// FreeRDP, so the shared library still exports the whole ABI.

#include "rdc_clipboard.h"

#include "rdc_core.h"

namespace rdc {

ClipboardBridge& ClipboardBridge::Instance() {
  static ClipboardBridge bridge;
  return bridge;
}

void ClipboardBridge::Attach(rdpContext* context) { (void)context; }

void ClipboardBridge::Detach() {}

void ClipboardBridge::SetLocalText(const uint16_t* code_units, int32_t length) {
  (void)code_units;
  (void)length;
}

int32_t ClipboardBridge::PendingLength() { return 0; }

int32_t ClipboardBridge::TakePending(uint16_t* out, int32_t capacity) {
  (void)out;
  (void)capacity;
  return RDC_ERR_NOT_IMPLEMENTED;
}

void ClipboardBridge::PumpOutgoing() {}

void ClipboardBridge::DeliverRemoteText(const uint16_t* code_units, int32_t length) {
  (void)code_units;
  (void)length;
}

std::u16string ClipboardBridge::LocalText() { return std::u16string(); }

}  // namespace rdc
