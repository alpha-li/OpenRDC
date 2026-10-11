// Text clipboard redirection over the cliprdr channel.
//
// Only text is handled. File and image transfer need the file-contents
// sub-protocol and a shared temporary directory, which is a much larger piece
// of work and not what the clipboard is used for in practice.
//
// The local clipboard belongs to the application, not to this class: Flutter
// reads and writes it, and pushes changes here. This side's job is to speak the
// protocol and to announce what the other end should know about.

#ifndef RDC_CLIPBOARD_H_
#define RDC_CLIPBOARD_H_

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>

#include "rdc_api.h"

/// Opaque to this header; the implementation includes the FreeRDP headers.
struct rdp_context;
typedef struct rdp_context rdpContext;

namespace rdc {

class ClipboardBridge {
 public:
  static ClipboardBridge& Instance();

  ClipboardBridge(const ClipboardBridge&) = delete;
  ClipboardBridge& operator=(const ClipboardBridge&) = delete;

  /// Registers the channel callbacks. Call once the connection is up, since the
  /// channel interface only exists after the channels are loaded.
  void Attach(rdpContext* context);

  /// Clears the callbacks and any pending text. Safe to call when not attached.
  void Detach();

  bool attached() const { return attached_.load(); }

  /// Announces new local clipboard text to the remote machine.
  ///
  /// Called from the UI thread. The text is copied and the actual protocol work
  /// happens on the session thread, because channel messaging is not documented
  /// as thread-safe.
  void SetLocalText(const uint16_t* code_units, int32_t length);

  /// Length in UTF-16 code units of the text most recently received from the
  /// remote machine, or 0 when there is none.
  int32_t PendingLength();

  /// Copies the pending text out and clears it. Returns the number of code
  /// units copied, or a negative RDC_ERR_* value.
  int32_t TakePending(uint16_t* out, int32_t capacity);

  /// A copy of the local clipboard text as last announced by the application,
  /// which is what gets handed to the remote machine when it asks.
  std::u16string LocalText();

  // --- called from the session thread ---------------------------------------

  /// Sends anything the UI has queued. Runs immediately before the event loop
  /// waits, so it executes on the session thread.
  void PumpOutgoing();

  /// Publishes text received from the remote machine and raises the event that
  /// tells the application to put it on the local clipboard.
  void DeliverRemoteText(const uint16_t* code_units, int32_t length);

 private:
  ClipboardBridge() = default;
  ~ClipboardBridge() = default;

  std::atomic<bool> attached_{false};

  std::atomic<void*> cliprdr_{nullptr};

  // Text waiting to be announced to the remote machine. Guarded because it is
  // written by the UI thread and drained by the session thread.
  std::mutex outgoing_mutex_;
  std::u16string outgoing_;
  bool outgoing_pending_ = false;

  // Text most recently received from the remote machine, waiting for the
  // application to collect it.
  std::mutex incoming_mutex_;
  std::u16string incoming_;
};

}  // namespace rdc

#endif  // RDC_CLIPBOARD_H_
