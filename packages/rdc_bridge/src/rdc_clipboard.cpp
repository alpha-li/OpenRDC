#include "rdc_clipboard.h"

// Two headers, deliberately: the client context and its callbacks live in
// freerdp/client/cliprdr.h, while the wire message structures are in
// freerdp/channels/cliprdr.h. Including only one leaves half the types
// undefined.
#include <freerdp/channels/channels.h>
#include <freerdp/channels/cliprdr.h>
#include <freerdp/client/cliprdr.h>
#include <freerdp/freerdp.h>

#include <cstring>

#include "rdc_core.h"

namespace rdc {
namespace {

/// Both ends speak CF_UNICODETEXT, which the protocol defines as UTF-16LE with
/// CRLF line endings. That is also what the Windows clipboard holds, so text
/// crosses the boundary unmodified apart from the newline convention, which the
/// application side handles.
constexpr UINT32 kTextFormatId = CF_UNICODETEXT;

CliprdrClientContext* AsCliprdr(void* raw) {
  return static_cast<CliprdrClientContext*>(raw);
}

/// Splits a UTF-16LE byte blob from the wire into code units.
///
/// The payload length is in bytes and is not required to be even; a trailing odd
/// byte would otherwise be read past the end.
std::u16string BytesToUnits(const BYTE* data, UINT32 byte_length) {
  if (data == nullptr || byte_length < 2) {
    return std::u16string();
  }
  const size_t units = byte_length / 2;
  std::u16string text(units, u'\0');
  std::memcpy(text.data(), data, units * sizeof(char16_t));
  return text;
}

}  // namespace

ClipboardBridge& ClipboardBridge::Instance() {
  static ClipboardBridge bridge;
  return bridge;
}

// ---------------------------------------------------------------------------
// Channel callbacks. All run on the session thread.
// ---------------------------------------------------------------------------

namespace {

UINT OnMonitorReady(CliprdrClientContext* cliprdr, const CLIPRDR_MONITOR_READY* /*ready*/) {
  Log("clipboard: channel ready");

  // Capabilities first, then the format list: the server needs to know we
  // support long format names before it can make sense of what we offer.
  if (cliprdr->ClientCapabilities != nullptr) {
    CLIPRDR_GENERAL_CAPABILITY_SET general = {};
    general.capabilitySetType = CB_CAPSTYPE_GENERAL;
    general.capabilitySetLength = CB_CAPSTYPE_GENERAL_LEN;
    general.version = CB_CAPS_VERSION_2;
    general.generalFlags = CB_USE_LONG_FORMAT_NAMES;

    CLIPRDR_CAPABILITIES capabilities = {};
    capabilities.cCapabilitiesSets = 1;
    capabilities.capabilitySets = reinterpret_cast<CLIPRDR_CAPABILITY_SET*>(&general);
    cliprdr->ClientCapabilities(cliprdr, &capabilities);
  }

  // Announce text support immediately. Without this the server has nothing to
  // request, so a paste into the remote session would find nothing on offer.
  if (cliprdr->ClientFormatList != nullptr) {
    CLIPRDR_FORMAT format = {};
    format.formatId = kTextFormatId;
    format.formatName = nullptr;

    CLIPRDR_FORMAT_LIST list = {};
    list.common.msgType = CB_FORMAT_LIST;
    list.common.msgFlags = 0;
    list.numFormats = 1;
    list.formats = &format;
    cliprdr->ClientFormatList(cliprdr, &list);
  }

  return CHANNEL_RC_OK;
}

UINT OnServerFormatList(CliprdrClientContext* cliprdr, const CLIPRDR_FORMAT_LIST* list) {
  if (cliprdr == nullptr || list == nullptr) {
    return ERROR_INVALID_PARAMETER;
  }

  bool has_text = false;
  for (UINT32 i = 0; i < list->numFormats; ++i) {
    if (list->formats[i].formatId == kTextFormatId) {
      has_text = true;
      break;
    }
  }

  // Acknowledge so the server does not retry the announcement.
  if (cliprdr->ClientFormatListResponse != nullptr) {
    CLIPRDR_FORMAT_LIST_RESPONSE response = {};
    response.common.msgType = CB_FORMAT_LIST_RESPONSE;
    response.common.msgFlags = CB_RESPONSE_OK;
    cliprdr->ClientFormatListResponse(cliprdr, &response);
  }

  if (!has_text) {
    return CHANNEL_RC_OK;
  }

  // Pull the text across straight away instead of waiting for a paste. The
  // remote clipboard changes far less often than it is pasted, so fetching once
  // is cheaper than a round trip per paste, and it means the local clipboard is
  // already correct by the time the user reaches for it.
  if (cliprdr->ClientFormatDataRequest != nullptr) {
    CLIPRDR_FORMAT_DATA_REQUEST request = {};
    request.common.msgType = CB_FORMAT_DATA_REQUEST;
    request.common.msgFlags = 0;
    request.requestedFormatId = kTextFormatId;
    cliprdr->ClientFormatDataRequest(cliprdr, &request);
  }

  return CHANNEL_RC_OK;
}

UINT OnServerFormatDataRequest(CliprdrClientContext* cliprdr,
                               const CLIPRDR_FORMAT_DATA_REQUEST* request) {
  if (cliprdr == nullptr || request == nullptr || cliprdr->ClientFormatDataResponse == nullptr) {
    return ERROR_INVALID_PARAMETER;
  }
  if (request->requestedFormatId != kTextFormatId) {
    return CHANNEL_RC_OK;
  }

  /* The text the application last put on the local clipboard. The bridge holds
   * a copy rather than reading the OS clipboard here, so the session thread
   * never waits on another thread's clipboard -- and so the text that is sent
   * is the one the format list announced, rather than whatever replaced it in
   * the meantime. */
  const std::u16string text = ClipboardBridge::Instance().LocalText();

  CLIPRDR_FORMAT_DATA_RESPONSE response = {};
  response.common.msgType = CB_FORMAT_DATA_RESPONSE;

  if (text.empty()) {
    response.common.msgFlags = CB_RESPONSE_FAIL;
    response.common.dataLen = 0;
    response.requestedFormatData = nullptr;
  } else {
    response.common.msgFlags = CB_RESPONSE_OK;
    response.common.dataLen = static_cast<UINT32>(text.size() * sizeof(char16_t));
    response.requestedFormatData = reinterpret_cast<const BYTE*>(text.data());
  }

  // The response is sent synchronously, so `text` outliving this call is not
  // required.
  return cliprdr->ClientFormatDataResponse(cliprdr, &response);
}

UINT OnServerFormatDataResponse(CliprdrClientContext* /*cliprdr*/,
                                const CLIPRDR_FORMAT_DATA_RESPONSE* response) {
  if (response == nullptr || (response->common.msgFlags & CB_RESPONSE_FAIL) != 0) {
    return CHANNEL_RC_OK;
  }

  const std::u16string text = BytesToUnits(response->requestedFormatData, response->common.dataLen);
  if (!text.empty()) {
    ClipboardBridge::Instance().DeliverRemoteText(
        reinterpret_cast<const uint16_t*>(text.data()), static_cast<int32_t>(text.size()));
  }
  return CHANNEL_RC_OK;
}

UINT OnServerCapabilities(CliprdrClientContext* /*cliprdr*/,
                          const CLIPRDR_CAPABILITIES* /*capabilities*/) {
  // Nothing to negotiate: this implementation offers text and only text, and
  // the server's capabilities do not change what it can accept.
  return CHANNEL_RC_OK;
}

}  // namespace

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------

void ClipboardBridge::Attach(rdpContext* context) {
  if (context == nullptr || context->channels == nullptr) {
    return;
  }

  auto* cliprdr = static_cast<CliprdrClientContext*>(
      freerdp_channels_get_static_channel_interface(context->channels, CLIPRDR_SVC_CHANNEL_NAME));
  if (cliprdr == nullptr) {
    // Not fatal: the channel may simply not be loaded, and a session without
    // clipboard redirection is still a working session.
    Log("clipboard: channel interface unavailable; redirection disabled");
    return;
  }

  cliprdr->MonitorReady = OnMonitorReady;
  cliprdr->ServerCapabilities = OnServerCapabilities;
  cliprdr->ServerFormatList = OnServerFormatList;
  cliprdr->ServerFormatDataRequest = OnServerFormatDataRequest;
  cliprdr->ServerFormatDataResponse = OnServerFormatDataResponse;

  cliprdr_.store(cliprdr);
  attached_.store(true);
  Log("clipboard: attached");
}

void ClipboardBridge::Detach() {
  attached_.store(false);
  cliprdr_.store(nullptr);

  std::lock_guard<std::mutex> outgoing_lock(outgoing_mutex_);
  outgoing_.clear();
  outgoing_pending_ = false;

  std::lock_guard<std::mutex> incoming_lock(incoming_mutex_);
  incoming_.clear();
}

// ---------------------------------------------------------------------------
// Application side
// ---------------------------------------------------------------------------

void ClipboardBridge::SetLocalText(const uint16_t* code_units, int32_t length) {
  if (code_units == nullptr || length <= 0) {
    return;
  }

  std::u16string text(reinterpret_cast<const char16_t*>(code_units),
                      static_cast<size_t>(length));

  std::lock_guard<std::mutex> lock(outgoing_mutex_);
  if (outgoing_ == text && outgoing_pending_) {
    // Already queued and unchanged; announcing it again would be noise.
    return;
  }
  outgoing_ = std::move(text);
  outgoing_pending_ = true;
}

void ClipboardBridge::PumpOutgoing() {
  std::u16string text;
  {
    std::lock_guard<std::mutex> lock(outgoing_mutex_);
    if (!outgoing_pending_) {
      return;
    }
    text = outgoing_;
    outgoing_pending_ = false;
  }

  CliprdrClientContext* cliprdr = AsCliprdr(cliprdr_.load());
  if (cliprdr == nullptr || cliprdr->ClientFormatList == nullptr) {
    return;
  }

  // Only the format list is announced, not the text: the server asks for the
  // contents only if something is actually pasted.
  CLIPRDR_FORMAT format = {};
  format.formatId = kTextFormatId;
  format.formatName = nullptr;

  CLIPRDR_FORMAT_LIST list = {};
  list.common.msgType = CB_FORMAT_LIST;
  list.common.msgFlags = 0;
  list.numFormats = 1;
  list.formats = &format;

  cliprdr->ClientFormatList(cliprdr, &list);
  Log("clipboard: announced local text (%zu code units)", text.size());
}

void ClipboardBridge::DeliverRemoteText(const uint16_t* code_units, int32_t length) {
  if (code_units == nullptr || length <= 0) {
    return;
  }

  {
    std::lock_guard<std::mutex> lock(incoming_mutex_);
    incoming_.assign(reinterpret_cast<const char16_t*>(code_units), static_cast<size_t>(length));
  }

  EmitRawEvent(RDC_EVENT_CLIPBOARD, length, "remote clipboard text");
}

std::u16string ClipboardBridge::LocalText() {
  std::lock_guard<std::mutex> lock(outgoing_mutex_);
  return outgoing_;
}

int32_t ClipboardBridge::PendingLength() {
  std::lock_guard<std::mutex> lock(incoming_mutex_);
  return static_cast<int32_t>(incoming_.size());
}

int32_t ClipboardBridge::TakePending(uint16_t* out, int32_t capacity) {
  if (out == nullptr || capacity <= 0) {
    return RDC_ERR_BAD_ARGUMENT;
  }

  std::lock_guard<std::mutex> lock(incoming_mutex_);
  const int32_t count =
      static_cast<int32_t>(incoming_.size() < static_cast<size_t>(capacity) ? incoming_.size()
                                                                             : capacity);
  if (count > 0) {
    std::memcpy(out, incoming_.data(), static_cast<size_t>(count) * sizeof(char16_t));
  }
  incoming_.clear();
  return count;
}

}  // namespace rdc
