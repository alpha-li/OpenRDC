// A live RDP session.
//
// One session per process, which matches how the app is used: a window is a
// connection. The session owns a worker thread that runs FreeRDP's event loop,
// because FreeRDP's input API carries no documented thread-safety guarantee and
// its framebuffer is only valid inside its own callbacks. Everything crossing
// that boundary is either a queued input event or a published frame slot.

#ifndef RDC_SESSION_H_
#define RDC_SESSION_H_

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "rdc_api.h"

/// Forward declaration so this header stays free of FreeRDP includes. Matches
/// the declaration in freerdp/types.h.
struct rdp_context;
typedef struct rdp_context rdpContext;

namespace rdc {

/// A pending input event. Deliberately plain data: the UI thread only ever
/// appends to the queue, and the session thread only ever consumes from it.
struct InputEvent {
  enum class Kind { kMouse, kKey, kText, kCtrlAltDel };

  Kind kind = Kind::kMouse;

  // kMouse
  int32_t action = 0;
  int32_t x = 0;
  int32_t y = 0;
  int32_t wheel_delta = 0;

  // kKey
  int32_t scancode = 0;
  int32_t down = 0;
  int32_t extended = 0;

  // kText, as UTF-16 code units
  std::u16string text;
};

class RdpSession {
 public:
  /// The process-wide session. A single instance is honest about the fact that
  /// the frame ring is process-wide too.
  static RdpSession& Instance();

  RdpSession(const RdpSession&) = delete;
  RdpSession& operator=(const RdpSession&) = delete;

  /// Copies `params`, starts the worker and returns immediately.
  /// Returns RDC_OK, RDC_ERR_ALREADY_RUNNING or RDC_ERR_BAD_ARGUMENT.
  int32_t Connect(const rdc_connect_params& params);

  /// Asks the worker to stop. Returns immediately; the session reports
  /// RDC_STATE_DISCONNECTED once it has torn down.
  void Disconnect();

  bool IsRunning() const { return running_.load(); }

  /// Records the display-control channel once the server opens it.
  void SetDisplayControl(void* disp);

  /// Subscribes to the dynamic-channel manager, which is how the
  /// display-control channel is discovered.
  void AttachDisplayControl(rdpContext* context);

  /// Queues a request for the remote desktop to change size. Applied on the
  /// session thread; the last request before a drain wins, so a window being
  /// dragged produces one resize rather than dozens.
  void QueueResize(int32_t width, int32_t height);

  /// Queues a local folder to expose as a network drive. Consumed by the next
  /// Connect, so the list never outlives the connection it was meant for.
  void AddRedirectedFolder(const std::string& name, const std::string& path);

  /// Queues "redirect every drive" for the next Connect.
  void SetRedirectAllDrives(bool enabled);

  /// Answers the certificate question the session thread is blocked on.
  /// Called from the UI thread; a no-op when nothing is pending.
  void RespondToCertificate(int32_t decision);

  /// Copies the pending certificate details into `out`. Returns RDC_OK, or
  /// RDC_ERR_BAD_ARGUMENT when nothing is pending.
  int32_t GetPendingCertificate(rdc_certificate_info* out);

  // Input entry points. All are safe to call from any thread and all return
  // immediately.
  void QueueMouse(int32_t action, int32_t x, int32_t y, int32_t wheel_delta);
  void QueueKey(int32_t scancode, int32_t down, int32_t extended);
  void QueueText(const uint16_t* code_units, int32_t length);
  void QueueCtrlAltDel();

  // --- called from FreeRDP callbacks, all on the worker thread --------------
  //
  // Public because FreeRDP takes plain C function pointers, which cannot carry
  // a `this`; the file-local trampolines in the .cpp have to reach these, and
  // Friending a function in an anonymous namespace is not expressible.

  /// The body of the session thread: creates the context, hands control to
  /// FreeRDP, then tears everything down. Blocks until the session ends.
  void WorkerMain();

  /// Connect and pump the event loop. This is what FreeRDP's ClientStart
  /// callback invokes, and it must not be the same function as [WorkerMain]:
  /// WorkerMain calls freerdp_client_start, which calls this, so sharing them
  /// would recurse.
  void RunSession();

  int OnClientNew(void* instance, void* context);
  void OnClientFree();
  bool OnPreConnect(void* instance);
  bool OnPostConnect(void* instance);
  void OnPostDisconnect();

  /// A batch of drawing operations has been applied; the primary buffer now
  /// holds a frame worth publishing.
  bool OnEndPaint();

  /// The remote desktop changed size. GDI rebuilds its buffer, so every cached
  /// pointer and geometry has to be re-read.
  bool OnDesktopResize();

  /// Certificate validation. Returns 1 to accept and remember, 2 to accept for
  /// this session only, 0 to reject.
  uint32_t OnVerifyCertificate(const char* host, uint16_t port, const char* common_name,
                               const char* subject, const char* issuer, const char* fingerprint,
                               uint32_t flags);

  /// Same, for a certificate that differs from the stored one. Must be handled:
  /// the inherited default prompts on a console that does not exist here.
  uint32_t OnVerifyChangedCertificate(const char* host, uint16_t port, const char* common_name,
                                      const char* subject, const char* issuer,
                                      const char* new_fingerprint, const char* old_subject,
                                      const char* old_issuer, const char* old_fingerprint,
                                      uint32_t flags);

  /// Called when the server asks for credentials the session does not have.
  bool OnAuthenticate(char** username, char** password, char** domain);

 private:
  RdpSession() = default;
  ~RdpSession();

  /// Everything the certificate prompt needs to show. Owned by the session
  /// because the pointers handed out through rdc_pending_certificate point in
  /// here.
  struct CertificateDetails {
    std::string host;
    int32_t port = 0;
    std::string common_name;
    std::string subject;
    std::string issuer;
    std::string fingerprint;
    std::string old_fingerprint;
    bool changed = false;
    bool name_mismatch = false;
  };

  void RunEventLoop();

  /// Publishes `details` and blocks until the application answers, or until the
  /// wait times out. Returns an RDC_CERT_* value.
  int32_t RequestCertificateDecision(const CertificateDetails& details);
  /// Sends everything queued so far. Runs on the worker thread, immediately
  /// before it goes back to waiting, so input is never dispatched concurrently
  /// with FreeRDP's own work.
  void DrainInput();

  /// Sends the pending resize request, if any. Runs on the worker thread for
  /// the same reason as DrainInput.
  void DrainResize();
  /// Copies the GDI primary buffer into the frame ring and publishes it.
  void PublishFrame();

  void EmitState(int32_t state, const char* message);
  void EmitError(int32_t code, const char* message);

  /// Reports FreeRDP's own last error, passing its code through unchanged and
  /// using its description. `stage` says what was being attempted, because the
  /// description alone does not.
  void EmitFreeRdpError(void* instance, const char* stage);

  /// A folder to expose to the session, staged between the caller's
  /// rdc_add_redirected_folder and the next Connect.
  struct RedirectedFolder {
    std::string name;
    std::string path;
  };

  struct ConnectParams {
    std::string hostname;
    int32_t port = 0;
    std::string username;
    std::string password;
    std::string domain;
    int32_t desktop_width = 0;
    int32_t desktop_height = 0;
    int32_t color_depth = 32;
    bool admin_session = false;
    bool ignore_certificate = false;
    bool reconnect_if_dropped = true;
    int32_t audio_playback = 0;
    bool use_multimon = false;
    bool use_gateway = false;
    bool gateway_bypass_local = true;
    std::string gateway_hostname;
    int32_t gateway_port = 0;
    std::string gateway_username;
    std::string gateway_password;
    std::string gateway_domain;
  };

  ConnectParams params_;

  // The redirection this connection actually uses, copied from the staged list
  // when Connect runs.
  std::vector<RedirectedFolder> redirected_folders_;
  bool redirect_all_drives_ = false;

  /// Staged before Connect, consumed by it. Guarded because the UI queues them
  /// while no session may yet be running.
  std::mutex redirect_mutex_;
  std::vector<RedirectedFolder> staged_folders_;
  bool staged_redirect_all_drives_ = false;

  std::thread worker_;
  std::atomic<bool> running_{false};
  std::atomic<bool> stop_requested_{false};

  /// Whether this connection ever reached the desktop.
  ///
  /// A connection that fails is torn down by FreeRDP from inside the failed
  /// connect, which raises the post-disconnect callback before the bridge has
  /// been able to report why. Reporting a disconnection there would put it ahead
  /// of the error that explains it, and a caller reacting to the disconnection
  /// would have nothing to go on.
  std::atomic<bool> connected_{false};

  /// Set on the worker thread, read by Disconnect(). `rdpContext` is opaque
  /// here so the header stays free of FreeRDP includes.
  std::atomic<void*> context_{nullptr};

  /// The display-control channel, once the server has offered it. Also opaque
  /// for the same reason. Null until then, and on hosts too old to have it.
  std::atomic<void*> display_control_{nullptr};

  std::mutex input_mutex_;
  std::deque<InputEvent> input_queue_;

  // The newest requested desktop size, or zeroes when none is pending. Kept as
  // a single slot rather than a queue: intermediate sizes during a drag are
  // worthless, only the size the user settled on matters.
  std::mutex resize_mutex_;
  int32_t pending_width_ = 0;
  int32_t pending_height_ = 0;

  // Certificate approval. The session thread blocks on cert_condition_ inside
  // the verification callback while the UI decides, so this is the one place
  // the bridge calls *into* the application and waits for an answer.
  std::mutex cert_mutex_;
  std::condition_variable cert_condition_;
  bool cert_pending_ = false;
  bool cert_answered_ = false;
  int32_t cert_decision_ = RDC_CERT_REJECT;

  CertificateDetails cert_details_;
};

}  // namespace rdc

#endif  // RDC_SESSION_H_
