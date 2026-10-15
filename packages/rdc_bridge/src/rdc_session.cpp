#include "rdc_session.h"

#include <freerdp/client.h>
#include <freerdp/client/disp.h>
#include <freerdp/client/drdynvc.h>
#include <freerdp/channels/channels.h>
#include <freerdp/client/cmdline.h>
#include <freerdp/display.h>
#include <freerdp/freerdp.h>
#include <freerdp/gdi/gdi.h>
#include <freerdp/input.h>
#include <freerdp/scancode.h>
#include <freerdp/settings.h>
#include <freerdp/update.h>
#include <winpr/synch.h>
#include <winpr/wlog.h>

#include <openssl/provider.h>

#include <chrono>
#include <cstdio>
#include <cstring>
#include <string>

#ifdef _WIN32
#include <windows.h>
#endif

#include "rdc_clipboard.h"
#include "rdc_cursor.h"
#include "rdc_core.h"

namespace rdc {
namespace {

/// The client context FreeRDP hands back to every callback.
///
/// `rdpClientContext` must be the first member and the allocation must be at
/// least its size: the client-common layer casts the context to
/// `rdpClientContext*` unconditionally and fails the session outright if
/// `ContextSize` is too small.
struct RdcClientContext {
  rdpClientContext client;
};

/// How long the event loop waits before re-checking the stop flag and the input
/// queue. Short enough that input feels immediate, long enough that an idle
/// session costs nothing measurable.
constexpr DWORD kLoopTimeoutMs = 20;

/// Formats a Win32 error from a FreeRDP failure for the event message.
std::string DescribeFailure(const char* stage, freerdp* instance) {
  const char* detail = "unknown error";
  if (instance != nullptr) {
    const UINT32 code = freerdp_get_last_error(instance->context);
    const char* name = freerdp_get_last_error_name(code);
    const char* description = freerdp_get_last_error_string(code);
    if (name != nullptr && description != nullptr) {
      detail = description;
      std::string combined = name;
      combined += ": ";
      combined += description;
      return std::string(stage) + " 失败 - " + combined;
    }
  }
  return std::string(stage) + " 失败 - " + detail;
}

RdpSession* SessionFrom(rdpContext* context) {
  // One session per process, and the frame ring it publishes into is
  // process-wide as well, so a singleton is the honest representation.
  (void)context;
  return &RdpSession::Instance();
}

/// Tells OpenSSL where the provider modules are, i.e. beside the executable.
///
/// This is not optional. OpenSSL 3 does not search next to the application, so
/// the legacy provider is never found; without it md4 is unavailable, NTLM is
/// consequently disabled, and NLA -- required by every modern Windows host --
/// cannot authenticate. The failure is a log warning and connections that stall
/// at "connecting", which is a miserable thing to diagnose.
///
/// The OPENSSL_MODULES environment variable would be the conventional answer,
/// but it does not work here: libcrypto resolves its module path during DLL
/// initialisation, which on this process happens before main() ever runs. Hence
/// the explicit call, which works whenever it is made.
void ConfigureOpenSslProviderPath() {
#ifdef _WIN32
  wchar_t module_path[MAX_PATH] = {};
  const DWORD length = GetModuleFileNameW(nullptr, module_path, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) {
    return;
  }

  std::wstring directory(module_path, length);
  const size_t separator = directory.find_last_of(L"\\/");
  if (separator == std::wstring::npos) {
    return;
  }
  directory.resize(separator);

  char utf8[MAX_PATH * 4] = {};
  const int written = WideCharToMultiByte(CP_UTF8, 0, directory.c_str(), -1, utf8, sizeof(utf8),
                                          nullptr, nullptr);
  if (written <= 0) {
    return;
  }

  OSSL_PROVIDER_set_default_search_path(nullptr, utf8);
#else
  // Elsewhere the provider modules live in the system OpenSSL layout, which is
  // found without help.
#endif
}

/// Called by the dynamic-channel manager as each channel is opened.
///
/// The display-control channel is created on demand -- the server only opens it
/// once the client has advertised support -- so it cannot be looked up by name
/// at connect time the way a static channel like the clipboard can. This
/// callback is how it is actually obtained.
UINT OnDrdynvcChannelConnected(DrdynvcClientContext* context, const char* name, void* pInterface) {
  /* FreeRDP installs its own handler here for the channels it manages itself,
   * so this one is chained on top of it rather than replacing it. Dropping the
   * original would break FreeRDP's own dynamic-channel dispatch. */
  static pcDrdynvcOnChannelConnected previous = nullptr;
  if (previous == nullptr) {
    previous = context != nullptr ? context->OnChannelConnected : nullptr;
  }

  Log("dynvc: channel \"%s\" connected", name != nullptr ? name : "(null)");

  if (name != nullptr && std::strcmp(name, DISP_DVC_CHANNEL_NAME) == 0 &&
      pInterface != nullptr) {
    RdpSession::Instance().SetDisplayControl(pInterface);
  }

  if (previous != nullptr && previous != OnDrdynvcChannelConnected) {
    return previous(context, name, pInterface);
  }
  return CHANNEL_RC_OK;
}

}  // namespace

// ---------------------------------------------------------------------------
// FreeRDP callbacks
//
// These are file-local statics rather than class members because FreeRDP takes
// plain C function pointers, which cannot carry a `this`. Each one forwards to
// the process-wide session.
// ---------------------------------------------------------------------------

namespace {

int ClientNewCallback(freerdp* instance, rdpContext* context) {
  return SessionFrom(context)->OnClientNew(instance, context) ? 1 : 0;
}

void ClientFreeCallback(freerdp* instance, rdpContext* context) {
  (void)instance;
  SessionFrom(context)->OnClientFree();
}

BOOL PreConnectCallback(freerdp* instance) {
  return SessionFrom(instance->context)->OnPreConnect(instance) ? TRUE : FALSE;
}

BOOL PostConnectCallback(freerdp* instance) {
  return SessionFrom(instance->context)->OnPostConnect(instance) ? TRUE : FALSE;
}

void PostDisconnectCallback(freerdp* instance) {
  SessionFrom(instance->context)->OnPostDisconnect();
}

BOOL EndPaintCallback(rdpContext* context) {
  return SessionFrom(context)->OnEndPaint() ? TRUE : FALSE;
}

BOOL DesktopResizeCallback(rdpContext* context) {
  return SessionFrom(context)->OnDesktopResize() ? TRUE : FALSE;
}

DWORD VerifyCertificateCallback(freerdp* instance, const char* host, UINT16 port,
                                const char* common_name, const char* subject, const char* issuer,
                                const char* fingerprint, DWORD flags) {
  return SessionFrom(instance->context)
      ->OnVerifyCertificate(host, port, common_name, subject, issuer, fingerprint, flags);
}

DWORD VerifyChangedCertificateCallback(freerdp* instance, const char* host, UINT16 port,
                                       const char* common_name, const char* subject,
                                       const char* issuer, const char* new_fingerprint,
                                       const char* old_subject, const char* old_issuer,
                                       const char* old_fingerprint, DWORD flags) {
  return SessionFrom(instance->context)
      ->OnVerifyChangedCertificate(host, port, common_name, subject, issuer, new_fingerprint,
                                   old_subject, old_issuer, old_fingerprint, flags);
}

BOOL AuthenticateCallback(freerdp* instance, char** username, char** password, char** domain,
                          rdp_auth_reason reason) {
  (void)reason;
  return SessionFrom(instance->context)->OnAuthenticate(username, password, domain) ? TRUE : FALSE;
}

int ClientStartCallback(rdpContext* context) {
  SessionFrom(context)->RunSession();
  return CHANNEL_RC_OK;
}

int ClientStopCallback(rdpContext* context) {
  (void)context;
  // The worker observes stop_requested_ on its next loop turn and tears itself
  // down; blocking here would stall whichever thread called rdc_disconnect.
  return CHANNEL_RC_OK;
}

BOOL GlobalInitCallback(void) {
  return TRUE;
}

void GlobalUninitCallback(void) {}

}  // namespace

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

RdpSession& RdpSession::Instance() {
  static RdpSession session;
  return session;
}

RdpSession::~RdpSession() { Disconnect(); }

int32_t RdpSession::Connect(const rdc_connect_params& params) {
  if (running_.load()) {
    return RDC_ERR_ALREADY_RUNNING;
  }
  if (params.hostname == nullptr || params.hostname[0] == '\0') {
    return RDC_ERR_BAD_ARGUMENT;
  }

  // Copy everything now: the caller's pointers only have to outlive this call.
  auto copy = [](const char* value) { return value != nullptr ? std::string(value) : std::string(); };

  params_.hostname = copy(params.hostname);
  params_.port = params.port;
  params_.username = copy(params.username);
  params_.password = copy(params.password);
  params_.domain = copy(params.domain);
  params_.desktop_width = params.desktop_width;
  params_.desktop_height = params.desktop_height;
  params_.color_depth = params.color_depth > 0 ? params.color_depth : 32;
  params_.admin_session = params.admin_session != 0;
  params_.ignore_certificate = params.ignore_certificate != 0;
  params_.reconnect_if_dropped = params.reconnect_if_dropped != 0;
  params_.audio_playback = params.audio_playback;
  params_.use_multimon = params.use_multimon != 0;
  params_.gateway_bypass_local = params.gateway_bypass_local != 0;
  params_.use_gateway = params.use_gateway != 0;
  params_.gateway_hostname = copy(params.gateway_hostname);
  params_.gateway_port = params.gateway_port;
  params_.gateway_username = copy(params.gateway_username);
  params_.gateway_password = copy(params.gateway_password);
  params_.gateway_domain = copy(params.gateway_domain);

  {
    std::lock_guard<std::mutex> lock(input_mutex_);
    input_queue_.clear();
  }

  // Take ownership of the staged redirection, so it applies to this
  // connection and to no later one.
  {
    std::lock_guard<std::mutex> lock(redirect_mutex_);
    redirected_folders_ = staged_folders_;
    redirect_all_drives_ = staged_redirect_all_drives_;
    staged_folders_.clear();
    staged_redirect_all_drives_ = false;
  }

  // Belt and braces with Disconnect(). The guard at the top of Connect() only
  // asks whether a session is *running*, and a worker that finished on its own
  // -- which is how every failed connection ends -- is not running yet is still
  // a joinable std::thread. Assigning over one terminates the process; joining
  // it first returns immediately.
  if (worker_.joinable()) {
    worker_.join();
  }

  // The ring outlives any one session, and the presenter goes on showing what it
  // last read whenever there is nothing to read. Left alone, that is the
  // previous connection's desktop -- still on screen for the whole of this
  // one's connect, and indistinguishable from the machine being connected to.
  // Emptying it here and saying so is what makes "nothing yet" mean blank
  // rather than out of date.
  Ring().Reset(0, 0);
  NotifyFrameReady();

  stop_requested_.store(false);
  connected_.store(false);
  running_.store(true);
  worker_ = std::thread([this] { WorkerMain(); });
  return RDC_OK;
}

void RdpSession::Disconnect() {
  // Deliberately not guarded on running_. The worker clears that flag itself,
  // one statement before it reports DISCONNECTED, so a caller reacting to a
  // connection that *failed* arrives too late to be told there is anything
  // running -- while the thread is still sitting there unjoined. A joinable
  // std::thread cannot be assigned over, and Start() assigns over this one, so
  // returning early here aborts the process on the next connection instead of
  // failing it. Joining a worker that has already finished costs nothing.
  stop_requested_.store(true);
  if (worker_.joinable()) {
    worker_.join();
  }
  running_.store(false);
}

// ---------------------------------------------------------------------------
// Worker
// ---------------------------------------------------------------------------

void RdpSession::WorkerMain() {
  // Before anything touches the protocol stack, so WinPR's OpenSSL
  // initialisation picks up the right module path.
  ConfigureOpenSslProviderPath();

  // Surface FreeRDP's own diagnostics when the bridge's are on; a connection
  // failure is far easier to attribute with the protocol stack talking.
  if (LogEnabled()) {
    wLog* root = WLog_GetRoot();
    WLog_SetLogAppenderType(root, WLOG_APPENDER_CONSOLE);
    WLog_SetLogLevel(root, WLOG_TRACE);
    Log("logging enabled; connecting to %s:%d as \"%s\"", params_.hostname.c_str(),
        params_.port > 0 ? params_.port : 3389, params_.username.c_str());
  }

  EmitState(RDC_STATE_CONNECTING, nullptr);

  RDP_CLIENT_ENTRY_POINTS_V1 entry_points = {};
  entry_points.Size = sizeof(entry_points);
  entry_points.Version = RDP_CLIENT_INTERFACE_VERSION;
  entry_points.ContextSize = sizeof(RdcClientContext);
  entry_points.ClientNew = ClientNewCallback;
  entry_points.ClientFree = ClientFreeCallback;
  entry_points.ClientStart = ClientStartCallback;
  entry_points.ClientStop = ClientStopCallback;
  entry_points.GlobalInit = GlobalInitCallback;
  entry_points.GlobalUninit = GlobalUninitCallback;

  rdpContext* context =
      freerdp_client_context_new(reinterpret_cast<RDP_CLIENT_ENTRY_POINTS*>(&entry_points));
  if (context == nullptr) {
    Log("freerdp_client_context_new returned null");
    EmitError(RDC_ERR_SESSION_CONTEXT, "could not create the RDP session context");
    EmitState(RDC_STATE_FAILED, nullptr);
    running_.store(false);
    return;
  }

  Log("context created");
  context_.store(context);

  // ClientStart is where the connect and the event loop happen; it blocks until
  // the loop exits, which is what this thread is for.
  const int rc = freerdp_client_start(context);
  if (rc != CHANNEL_RC_OK) {
    Log("freerdp_client_start returned %d", rc);
    EmitError(RDC_ERR_SESSION_START, "the session failed to start");
  }
  Log("session finished, tearing down");

  freerdp_client_context_free(context);
  context_.store(nullptr);

  running_.store(false);
  EmitState(RDC_STATE_DISCONNECTED, nullptr);
}

void RdpSession::RunEventLoop() {
  rdpContext* context = static_cast<rdpContext*>(context_.load());
  if (context == nullptr) {
    return;
  }

  HANDLE handles[64];
  while (!stop_requested_.load()) {
    // Input and clipboard announcements go out immediately before waiting, so
    // they are only ever dispatched from this thread, never concurrently with
    // FreeRDP's own processing.
    DrainInput();
    ClipboardBridge::Instance().PumpOutgoing();
    DrainResize();

    if (freerdp_shall_disconnect_context(context)) {
      break;
    }

    const DWORD count = freerdp_get_event_handles(context, handles, ARRAYSIZE(handles));
    if (count == 0) {
      EmitError(RDC_ERR_EVENT_HANDLES, "could not obtain the session event handles");
      break;
    }

    const DWORD status = WaitForMultipleObjects(count, handles, FALSE, kLoopTimeoutMs);
    if (status == WAIT_FAILED) {
      EmitError(RDC_ERR_EVENT_WAIT, "waiting on session events failed");
      break;
    }

    if (!freerdp_check_event_handles(context)) {
      const UINT32 code = freerdp_get_last_error(context);
      EmitError(static_cast<int32_t>(code), DescribeFailure("handling session data", context->instance).c_str());
      break;
    }
  }
}

// ---------------------------------------------------------------------------
// FreeRDP callbacks, dispatched from the worker thread
// ---------------------------------------------------------------------------

int RdpSession::OnClientNew(void* instance_ptr, void* context_ptr) {
  freerdp* instance = static_cast<freerdp*>(instance_ptr);
  rdpContext* context = static_cast<rdpContext*>(context_ptr);

  // Replace the client-common defaults, which prompt on the console. An
  // embedded client has no console and must answer through the UI instead.
  instance->PreConnect = PreConnectCallback;
  instance->PostConnect = PostConnectCallback;
  instance->PostDisconnect = PostDisconnectCallback;
  instance->VerifyCertificateEx = VerifyCertificateCallback;
  instance->VerifyChangedCertificateEx = VerifyChangedCertificateCallback;
  instance->AuthenticateEx = AuthenticateCallback;

  context->update->EndPaint = EndPaintCallback;
  context->update->DesktopResize = DesktopResizeCallback;

  return 1;
}

void RdpSession::OnClientFree() {}

bool RdpSession::OnPreConnect(void* instance_ptr) {
  freerdp* instance = static_cast<freerdp*>(instance_ptr);
  rdpSettings* settings = instance->context->settings;

  auto set_string = [settings](FreeRDP_Settings_Keys_String key, const std::string& value) {
    if (!value.empty()) {
      freerdp_settings_set_string(settings, key, value.c_str());
    }
  };

  set_string(FreeRDP_ServerHostname, params_.hostname);
  freerdp_settings_set_uint32(settings, FreeRDP_ServerPort,
                              params_.port > 0 ? static_cast<UINT32>(params_.port) : 3389);
  set_string(FreeRDP_Username, params_.username);
  set_string(FreeRDP_Password, params_.password);
  set_string(FreeRDP_Domain, params_.domain);

  freerdp_settings_set_uint32(
      settings, FreeRDP_DesktopWidth,
      params_.desktop_width > 0 ? static_cast<UINT32>(params_.desktop_width) : 1280);
  freerdp_settings_set_uint32(
      settings, FreeRDP_DesktopHeight,
      params_.desktop_height > 0 ? static_cast<UINT32>(params_.desktop_height) : 720);
  freerdp_settings_set_uint32(settings, FreeRDP_ColorDepth,
                              static_cast<UINT32>(params_.color_depth));

  // Negotiate with modern security only. RDP security is broken and only
  // needed for hosts old enough that they cannot do TLS.
  freerdp_settings_set_bool(settings, FreeRDP_NlaSecurity, TRUE);
  freerdp_settings_set_bool(settings, FreeRDP_TlsSecurity, TRUE);
  freerdp_settings_set_bool(settings, FreeRDP_RdpSecurity, FALSE);

  /* Force the software GDI path. With a hardware or GFX-only path the primary
   * buffer is left empty by design, which would show up as a permanently black
   * desktop with no error anywhere. */
  freerdp_settings_set_bool(settings, FreeRDP_SoftwareGdi, TRUE);

  /* Redirection. Only one of the two forms is meaningful: naming specific
   * folders, or asking for every drive.
   *
   * The device channel takes its arguments as {"drive", <path>, <name>} --
   * path before name, which reads backwards and is easy to get wrong. With only
   * two arguments the second is the drive letter or "*", with no path. */
  {
    std::lock_guard<std::mutex> lock(redirect_mutex_);
    for (const RedirectedFolder& folder : redirected_folders_) {
      const char* params[] = {"drive", folder.path.c_str(), folder.name.c_str()};
      if (!freerdp_client_add_device_channel(settings, 3, params)) {
        Log("redirect: refused folder \"%s\"", folder.path.c_str());
      } else {
        Log("redirect: exposing \"%s\" as \"%s\"", folder.path.c_str(), folder.name.c_str());
      }
    }
    if (redirect_all_drives_) {
      const char* params[] = {"drive", "*"};
      if (!freerdp_client_add_device_channel(settings, 2, params)) {
        Log("redirect: refused all drives");
      } else {
        Log("redirect: exposing every drive");
      }
    }
  }

  /* Display control, so the desktop can follow the window. Both flags are
   * needed: the first advertises the capability, the second tells FreeRDP to
   * keep the session's notion of the desktop in step with the layout messages
   * rather than treating them as one-off. Announcing the capability is harmless
   * on its own -- a host that does not support it simply never offers the
   * channel, and nothing is sent until rdc_resize_desktop asks. */
  freerdp_settings_set_bool(settings, FreeRDP_SupportDisplayControl, TRUE);
  freerdp_settings_set_bool(settings, FreeRDP_DynamicResolutionUpdate, TRUE);

  freerdp_settings_set_bool(settings, FreeRDP_ConsoleSession,
                            params_.admin_session ? TRUE : FALSE);
  freerdp_settings_set_bool(settings, FreeRDP_IgnoreCertificate,
                            params_.ignore_certificate ? TRUE : FALSE);

  /* Where remote audio is played.
   *
   * Two booleans rather than one mode, which reads oddly but is what the
   * protocol settings actually are, and how FreeRDP's own command line
   * translates its /sound:xxx switch: playing here means AudioPlayback,
   * playing there means RemoteConsoleAudio, and never means neither. */
  switch (params_.audio_playback) {
    case RDC_AUDIO_ON_REMOTE:
      freerdp_settings_set_bool(settings, FreeRDP_AudioPlayback, FALSE);
      freerdp_settings_set_bool(settings, FreeRDP_RemoteConsoleAudio, TRUE);
      break;
    case RDC_AUDIO_NEVER:
      freerdp_settings_set_bool(settings, FreeRDP_AudioPlayback, FALSE);
      freerdp_settings_set_bool(settings, FreeRDP_RemoteConsoleAudio, FALSE);
      break;
    case RDC_AUDIO_ON_THIS_COMPUTER:
    default:
      freerdp_settings_set_bool(settings, FreeRDP_AudioPlayback, TRUE);
      freerdp_settings_set_bool(settings, FreeRDP_RemoteConsoleAudio, FALSE);
      break;
  }

  /* Automatic reconnection after a dropped connection. FreeRDP retries the
   * session rather than the caller having to notice and reconnect, which is
   * what makes a brief network blip survivable. */
  freerdp_settings_set_bool(settings, FreeRDP_AutoReconnectionEnabled,
                            params_.reconnect_if_dropped ? TRUE : FALSE);
  if (params_.reconnect_if_dropped) {
    freerdp_settings_set_uint32(settings, FreeRDP_AutoReconnectMaxRetries, 20);
  }

  /* Spanning every local monitor. The monitor definitions themselves come from
   * FreeRDP's own detection of the local displays, so there is nothing to fill
   * in here beyond the intent. */
  if (params_.use_multimon) {
    if (!freerdp_settings_set_bool(settings, FreeRDP_UseMultimon, TRUE)) {
      Log("multimon: this build cannot span monitors");
    }
  }

  if (params_.use_gateway && !params_.gateway_hostname.empty()) {
    freerdp_settings_set_bool(settings, FreeRDP_GatewayEnabled, TRUE);
    set_string(FreeRDP_GatewayHostname, params_.gateway_hostname);
    freerdp_settings_set_uint32(
        settings, FreeRDP_GatewayPort,
        params_.gateway_port > 0 ? static_cast<UINT32>(params_.gateway_port) : 443);
    set_string(FreeRDP_GatewayUsername, params_.gateway_username);
    set_string(FreeRDP_GatewayPassword, params_.gateway_password);
    set_string(FreeRDP_GatewayDomain, params_.gateway_domain);
    freerdp_settings_set_bool(
        settings, FreeRDP_GatewayUseSameCredentials,
        params_.gateway_username.empty() ? TRUE : FALSE);
    freerdp_settings_set_bool(settings, FreeRDP_GatewayBypassLocal,
                              params_.gateway_bypass_local ? TRUE : FALSE);
  }

  return true;
}

bool RdpSession::OnPostConnect(void* instance_ptr) {
  freerdp* instance = static_cast<freerdp*>(instance_ptr);

  /* gdi_init must be called here rather than in PreConnect. Since FreeRDP 3.31
   * gdi_init_ex no longer creates context->cache, and calling it before the
   * connection exists dereferences a null cache. */
  if (!gdi_init(instance, PIXEL_FORMAT_RGBA32)) {
    EmitError(RDC_ERR_GDI_INIT, "could not initialise GDI rendering");
    return false;
  }

  const rdpGdi* gdi = instance->context->gdi;
  Ring().Reset(gdi->width, gdi->height);

  Log("connected, desktop %dx%d stride %u", gdi->width, gdi->height, gdi->stride);
  EmitDesktopSize(gdi->width, gdi->height);

  /* Here rather than after freerdp_connect returns, which is the clipboard's
   * rule: the core installs its own pointer cache over these callbacks
   * immediately before PostConnect runs, so this is the first moment an
   * override sticks -- and doing it here also covers a reconnect, which runs
   * PostConnect again. */
  InstallCursorCapture(instance->context);

  connected_.store(true);
  EmitState(RDC_STATE_CONNECTED, nullptr);
  return true;
}

void RdpSession::RunSession() {
  rdpContext* context = static_cast<rdpContext*>(context_.load());
  if (context == nullptr) {
    return;
  }
  freerdp* instance = context->instance;

  if (!freerdp_connect(instance)) {
    EmitFreeRdpError(instance, "connect");
    return;
  }

  /* Attach the clipboard only once freerdp_connect has returned. The channel
   * interfaces do not exist earlier: FreeRDP calls PostConnect and only then
   * calls freerdp_channels_post_connect, so a lookup from inside PostConnect
   * finds nothing and clipboard redirection silently stays off. */
  ClipboardBridge::Instance().Attach(context);
  AttachDisplayControl(context);

  RunEventLoop();

  ClipboardBridge::Instance().Detach();
  // The next session must not start out showing the last one's pointer.
  ResetCursor();
  display_control_.store(nullptr);

  if (context->gdi != nullptr) {
    gdi_free(instance);
  }
  freerdp_disconnect(instance);
}

void RdpSession::OnPostDisconnect() {
  // Only a session that was up disconnects in any sense the caller cares about.
  // FreeRDP also raises this while tearing down a connection that never came
  // up, and that one lands before the error explaining the failure -- so
  // reporting it would announce the session ending first and the reason second,
  // which is the wrong way round for anyone reacting to it. The worker reports
  // DISCONNECTED once it has finished tearing down either way, so nothing is
  // lost by staying quiet here.
  if (!connected_.load()) {
    return;
  }
  EmitState(RDC_STATE_DISCONNECTED, nullptr);
}

bool RdpSession::OnEndPaint() {
  PublishFrame();
  return true;
}

bool RdpSession::OnDesktopResize() {
  rdpContext* context = static_cast<rdpContext*>(context_.load());
  if (context == nullptr || context->gdi == nullptr) {
    return true;
  }

  /* GDI recreates its primary buffer on resize, so every cached pointer and
   * dimension is stale by this point and must be re-read. */
  const rdpGdi* gdi = context->gdi;
  Ring().Reset(gdi->width, gdi->height);
  EmitDesktopSize(gdi->width, gdi->height);
  return true;
}

uint32_t RdpSession::OnVerifyCertificate(const char* host, uint16_t port, const char* common_name,
                                         const char* subject, const char* issuer,
                                         const char* fingerprint, uint32_t flags) {
  CertificateDetails details;
  details.host = host != nullptr ? host : "";
  details.port = port;
  details.common_name = common_name != nullptr ? common_name : "";
  details.subject = subject != nullptr ? subject : "";
  details.issuer = issuer != nullptr ? issuer : "";
  details.fingerprint = fingerprint != nullptr ? fingerprint : "";

  /* These flags mean different things and must not be conflated:
   *
   *   CHANGED  - differs from the certificate previously accepted for this
   *              host. This is the one that looks like interception.
   *   MISMATCH - the name in the certificate is not the host being connected
   *              to. Serious too, and worth saying so, but it does not mean
   *              anyone is in the middle.
   *   LEGACY   - a self-signed certificate that cannot be chain-verified. This
   *              is the ordinary case for a workgroup machine and is what every
   *              first connection to one looks like, so treating it as
   *              suspicious would cry wolf on every new host -- and, worse,
   *              train the user to click through the prompt that does matter.
   */
  details.changed = (flags & VERIFY_CERT_FLAG_CHANGED) != 0;
  details.name_mismatch = (flags & VERIFY_CERT_FLAG_MISMATCH) != 0;

  return static_cast<uint32_t>(RequestCertificateDecision(details));
}

uint32_t RdpSession::OnVerifyChangedCertificate(const char* host, uint16_t port,
                                                const char* common_name, const char* subject,
                                                const char* issuer, const char* new_fingerprint,
                                                const char* old_subject, const char* old_issuer,
                                                const char* old_fingerprint, uint32_t flags) {
  (void)old_subject;
  (void)old_issuer;
  (void)flags;

  /* This must be handled explicitly. The client-common default prompts on a
   * console, and an embedded client has none, so leaving it in place cancels
   * the connection outright. */
  CertificateDetails details;
  details.host = host != nullptr ? host : "";
  details.port = port;
  details.common_name = common_name != nullptr ? common_name : "";
  details.subject = subject != nullptr ? subject : "";
  details.issuer = issuer != nullptr ? issuer : "";
  details.fingerprint = new_fingerprint != nullptr ? new_fingerprint : "";
  details.old_fingerprint = old_fingerprint != nullptr ? old_fingerprint : "";
  details.changed = true;

  return static_cast<uint32_t>(RequestCertificateDecision(details));
}

int32_t RdpSession::RequestCertificateDecision(const CertificateDetails& details) {
  // An explicit opt-out is taken at face value: the user configured this
  // connection not to check, so asking would contradict the setting.
  if (params_.ignore_certificate) {
    return RDC_CERT_ACCEPT_STORE;
  }

  {
    std::lock_guard<std::mutex> lock(cert_mutex_);
    cert_details_ = details;
    cert_pending_ = true;
    cert_answered_ = false;
    cert_decision_ = RDC_CERT_REJECT;
  }

  EmitState(RDC_STATE_AUTHENTICATING, details.changed ? "远程电脑的证书与已保存的不一致"
                                                      : "无法验证远程电脑的身份");

  EmitRawEvent(RDC_EVENT_CERTIFICATE, details.changed ? 1 : 0,
               TempMessage("%s:%d", details.host.c_str(), details.port));

  int32_t decision = RDC_CERT_REJECT;
  {
    std::unique_lock<std::mutex> lock(cert_mutex_);
    // Bounded wait: a UI that never answers -- because it crashed, or because
    // no one is looking at it -- must not leave this thread blocked forever.
    const bool answered =
        cert_condition_.wait_for(lock, std::chrono::minutes(1), [this] { return cert_answered_; });
    decision = answered ? cert_decision_ : RDC_CERT_REJECT;
    cert_pending_ = false;
    if (!answered) {
      Log("certificate prompt timed out; rejecting");
    }
  }

  /* "Accept for this session only" is deliberately not offered, and would not
   * work if it were: FreeRDP re-verifies the certificate against its store
   * while setting up NLA, so a certificate that was accepted but not stored
   * fails the connection with ERRCONNECT_TLS_CONNECT_FAILED. Every acceptance
   * therefore stores, and the UI says so rather than offering a choice it
   * cannot honour. */
  return decision == RDC_CERT_ACCEPT_ONCE ? RDC_CERT_ACCEPT_STORE : decision;
}

void RdpSession::RespondToCertificate(int32_t decision) {
  {
    std::lock_guard<std::mutex> lock(cert_mutex_);
    if (!cert_pending_) {
      return;
    }
    cert_decision_ = decision;
    cert_answered_ = true;
  }
  cert_condition_.notify_all();
}

int32_t RdpSession::GetPendingCertificate(rdc_certificate_info* out) {
  if (out == nullptr) {
    return RDC_ERR_BAD_ARGUMENT;
  }

  std::lock_guard<std::mutex> lock(cert_mutex_);
  if (!cert_pending_) {
    return RDC_ERR_BAD_ARGUMENT;
  }

  out->host = cert_details_.host.c_str();
  out->port = cert_details_.port;
  out->common_name = cert_details_.common_name.c_str();
  out->subject = cert_details_.subject.c_str();
  out->issuer = cert_details_.issuer.c_str();
  out->fingerprint = cert_details_.fingerprint.c_str();
  out->changed = cert_details_.changed ? 1 : 0;
  out->name_mismatch = cert_details_.name_mismatch ? 1 : 0;
  out->old_fingerprint = cert_details_.old_fingerprint.c_str();
  return RDC_OK;
}

bool RdpSession::OnAuthenticate(char** username, char** password, char** domain) {
  (void)username;
  (void)password;
  (void)domain;

  /* FreeRDP calls this only when the settings did not carry enough to
   * authenticate, which in practice means no password. Returning false makes it
   * abandon the connection, so say why first: the raw failure is an opaque
   * "connect cancelled" that gives the user nothing to act on.
   *
   * The settings already hold whatever was supplied, and the UI collects
   * credentials before connecting, so re-supplying them here would just produce
   * a retry loop that looks like a permanently wrong password. */
  EmitState(RDC_STATE_AUTHENTICATING, "需要用户名和密码");
  EmitError(RDC_ERR_NO_CREDENTIALS, "the remote PC requires a user name and password");
  return false;
}

// ---------------------------------------------------------------------------
// Frame publishing
// ---------------------------------------------------------------------------

void RdpSession::PublishFrame() {
  rdpContext* context = static_cast<rdpContext*>(context_.load());
  if (context == nullptr || context->gdi == nullptr) {
    return;
  }

  const rdpGdi* gdi = context->gdi;
  if (gdi->primary_buffer == nullptr || gdi->width <= 0 || gdi->height <= 0) {
    return;
  }

  FrameRing& ring = Ring();
  if (!ring.IsAllocated() || ring.width() != gdi->width || ring.height() != gdi->height) {
    return;
  }

  uint8_t* destination = ring.BeginWrite();
  if (destination == nullptr) {
    return;
  }

  /* The whole surface is copied rather than just the damaged region reported in
   * gdi->primary->hdc->hwnd->invalid. Copying everything costs a few megabytes
   * per frame, which is nothing next to the network traffic, and it removes a
   * whole class of bug where an update is missed because the damage region was
   * misread or the buffer was recreated underneath us. */
  const size_t source_stride = gdi->stride;
  const size_t row_bytes = static_cast<size_t>(ring.width()) * FrameRing::kBytesPerPixel;
  const size_t rows = static_cast<size_t>(ring.height());

  if (source_stride == row_bytes) {
    std::memcpy(destination, gdi->primary_buffer, row_bytes * rows);
  } else {
    // GDI may pad scanlines; copy row by row so the ring holds a tight image,
    // which is what the Flutter pixel buffer descriptor expects.
    const size_t copy_bytes = row_bytes < source_stride ? row_bytes : source_stride;
    for (size_t y = 0; y < rows; ++y) {
      std::memcpy(destination + y * row_bytes, gdi->primary_buffer + y * source_stride, copy_bytes);
    }
  }

  ring.EndWrite();
  NotifyFrameReady();
}

// ---------------------------------------------------------------------------
// Input
// ---------------------------------------------------------------------------

void RdpSession::QueueMouse(int32_t action, int32_t x, int32_t y, int32_t wheel_delta) {
  std::lock_guard<std::mutex> lock(input_mutex_);
  InputEvent event;
  event.kind = InputEvent::Kind::kMouse;
  event.action = action;
  event.x = x;
  event.y = y;
  event.wheel_delta = wheel_delta;
  input_queue_.push_back(std::move(event));
}

void RdpSession::QueueKey(int32_t scancode, int32_t down, int32_t extended) {
  std::lock_guard<std::mutex> lock(input_mutex_);
  InputEvent event;
  event.kind = InputEvent::Kind::kKey;
  event.scancode = scancode;
  event.down = down;
  event.extended = extended;
  input_queue_.push_back(std::move(event));
}

void RdpSession::QueueText(const uint16_t* code_units, int32_t length) {
  if (code_units == nullptr || length <= 0) {
    return;
  }
  std::u16string text(reinterpret_cast<const char16_t*>(code_units),
                      static_cast<size_t>(length));

  std::lock_guard<std::mutex> lock(input_mutex_);
  InputEvent event;
  event.kind = InputEvent::Kind::kText;
  event.text = std::move(text);
  input_queue_.push_back(std::move(event));
}

void RdpSession::AddRedirectedFolder(const std::string& name, const std::string& path) {
  if (path.empty()) {
    return;
  }
  std::lock_guard<std::mutex> lock(redirect_mutex_);
  staged_folders_.push_back(RedirectedFolder{name, path});
}

void RdpSession::SetRedirectAllDrives(bool enabled) {
  std::lock_guard<std::mutex> lock(redirect_mutex_);
  staged_redirect_all_drives_ = enabled;
}

void RdpSession::QueueResize(int32_t width, int32_t height) {
  if (width <= 0 || height <= 0) {
    return;
  }
  std::lock_guard<std::mutex> lock(resize_mutex_);
  pending_width_ = width;
  pending_height_ = height;
}

void RdpSession::SetDisplayControl(void* disp) {
  display_control_.store(disp);
  Log("resize: display control channel available");
}

/// Subscribes to the dynamic-channel manager so the display-control channel can
/// be picked up whenever the server gets round to opening it.
void RdpSession::AttachDisplayControl(rdpContext* context) {
  if (context == nullptr || context->channels == nullptr) {
    return;
  }

  auto* drdynvc = static_cast<DrdynvcClientContext*>(
      freerdp_channels_get_static_channel_interface(context->channels, DRDYNVC_SVC_CHANNEL_NAME));
  if (drdynvc == nullptr) {
    Log("resize: dynamic channel manager unavailable; resolution will not follow the window");
    return;
  }
  drdynvc->OnChannelConnected = OnDrdynvcChannelConnected;
  Log("resize: subscribed to dynamic channels");
}

void RdpSession::DrainResize() {
  int32_t width = 0;
  int32_t height = 0;
  {
    std::lock_guard<std::mutex> lock(resize_mutex_);
    if (pending_width_ <= 0 || pending_height_ <= 0) {
      return;
    }
    width = pending_width_;
    height = pending_height_;
    pending_width_ = 0;
    pending_height_ = 0;
  }

  auto* disp = static_cast<DispClientContext*>(display_control_.load());
  if (disp == nullptr) {
    /* Try the channel manager directly before giving up. A dynamic channel
     * registers an interface the same way a static one does, so this can
     * succeed once the server has opened it -- and it is the only route
     * available: the channel-connected notification needs
     * PubSub_SubscribeChannelConnected, which this build does not export. */
    rdpContext* context = static_cast<rdpContext*>(context_.load());
    if (context != nullptr && context->channels != nullptr) {
      disp = static_cast<DispClientContext*>(freerdp_channels_get_static_channel_interface(
          context->channels, DISP_DVC_CHANNEL_NAME));
      if (disp != nullptr) {
        display_control_.store(disp);
        Log("resize: display control channel found");
      }
    }
  }

  if (disp == nullptr || disp->SendMonitorLayout == nullptr) {
    // Either the server never offered display control, or it has not yet. The
    // desktop simply keeps its size; the caller notices by never receiving a
    // new desktop-size event.
    Log("resize: no display control channel; %dx%d dropped", width, height);
    return;
  }

  /* A single monitor covering the whole desktop. The layout is always sent in
   * full -- the protocol has no notion of a partial update -- and exactly one
   * monitor in a layout must carry the primary flag.
   *
   * This must go through the channel context's own SendMonitorLayout. The
   * freerdp_display_send_monitor_layout helper writes the older 20-byte
   * layout, which the dynamic channel the server actually opens does not
   * expect; sending it kills the connection rather than resizing it. */
  DISPLAY_CONTROL_MONITOR_LAYOUT monitor = {};
  monitor.Flags = DISPLAY_CONTROL_MONITOR_PRIMARY;
  monitor.Left = 0;
  monitor.Top = 0;
  monitor.Width = static_cast<UINT32>(width);
  monitor.Height = static_cast<UINT32>(height);
  // Physical size in millimetres, derived from a nominal 96 dpi, so the host can
  // reason about the display's real dimensions. It must be non-zero and within
  // the protocol's limits.
  monitor.PhysicalWidth = static_cast<UINT32>(width * 254 / 960);
  monitor.PhysicalHeight = static_cast<UINT32>(height * 254 / 960);
  monitor.Orientation = 0;  // landscape
  monitor.DesktopScaleFactor = 100;
  monitor.DeviceScaleFactor = 100;

  const UINT rc = disp->SendMonitorLayout(disp, 1, &monitor);
  if (rc != CHANNEL_RC_OK) {
    Log("resize: channel rejected %dx%d (rc=%u)", width, height, rc);
    return;
  }
  Log("resize: requested %dx%d", width, height);
}

void RdpSession::QueueCtrlAltDel() {
  std::lock_guard<std::mutex> lock(input_mutex_);
  InputEvent event;
  event.kind = InputEvent::Kind::kCtrlAltDel;
  input_queue_.push_back(std::move(event));
}

void RdpSession::DrainInput() {
  std::deque<InputEvent> pending;
  {
    std::lock_guard<std::mutex> lock(input_mutex_);
    if (input_queue_.empty()) {
      return;
    }
    // Swapped out so the lock covers a pointer move rather than however long
    // dispatching takes.
    pending.swap(input_queue_);
  }

  rdpContext* context = static_cast<rdpContext*>(context_.load());
  if (context == nullptr) {
    return;
  }
  rdpInput* input = context->input;
  if (input == nullptr) {
    return;
  }

  for (const InputEvent& event : pending) {
    switch (event.kind) {
      case InputEvent::Kind::kMouse: {
        const UINT16 x = static_cast<UINT16>(event.x);
        const UINT16 y = static_cast<UINT16>(event.y);
        switch (event.action) {
          case RDC_MOUSE_MOVE:
            freerdp_input_send_mouse_event(input, PTR_FLAGS_MOVE, x, y);
            break;
          case RDC_MOUSE_LEFT_DOWN:
            freerdp_input_send_mouse_event(input, PTR_FLAGS_BUTTON1 | PTR_FLAGS_DOWN, x, y);
            break;
          case RDC_MOUSE_LEFT_UP:
            freerdp_input_send_mouse_event(input, PTR_FLAGS_BUTTON1, x, y);
            break;
          case RDC_MOUSE_RIGHT_DOWN:
            freerdp_input_send_mouse_event(input, PTR_FLAGS_BUTTON2 | PTR_FLAGS_DOWN, x, y);
            break;
          case RDC_MOUSE_RIGHT_UP:
            freerdp_input_send_mouse_event(input, PTR_FLAGS_BUTTON2, x, y);
            break;
          case RDC_MOUSE_MIDDLE_DOWN:
            freerdp_input_send_mouse_event(input, PTR_FLAGS_BUTTON3 | PTR_FLAGS_DOWN, x, y);
            break;
          case RDC_MOUSE_MIDDLE_UP:
            freerdp_input_send_mouse_event(input, PTR_FLAGS_BUTTON3, x, y);
            break;
          case RDC_MOUSE_WHEEL: {
            /* One notch is 120 in the Windows convention. Sending a bare
             * wheel flag with no rotation is what makes the server drop the
             * connection, so a zero delta is skipped rather than sent. */
            if (event.wheel_delta == 0) {
              break;
            }
            const UINT16 magnitude =
                static_cast<UINT16>(event.wheel_delta > 0 ? event.wheel_delta : -event.wheel_delta);
            UINT16 flags = PTR_FLAGS_WHEEL | (magnitude & WheelRotationMask);
            if (event.wheel_delta < 0) {
              flags |= PTR_FLAGS_WHEEL_NEGATIVE;
            }
            freerdp_input_send_mouse_event(input, flags, x, y);
            break;
          }
          default:
            break;
        }
        break;
      }
      case InputEvent::Kind::kKey: {
        const UINT32 scancode =
            MAKE_RDP_SCANCODE(static_cast<UINT8>(event.scancode), event.extended != 0);
        freerdp_input_send_keyboard_event_ex(input, event.down != 0, FALSE, scancode);
        break;
      }
      case InputEvent::Kind::kText: {
        for (char16_t unit : event.text) {
          const UINT16 code = static_cast<UINT16>(unit);
          freerdp_input_send_unicode_keyboard_event(input, KBD_FLAGS_DOWN, code);
          freerdp_input_send_unicode_keyboard_event(input, KBD_FLAGS_RELEASE, code);
        }
        break;
      }
      case InputEvent::Kind::kCtrlAltDel: {
        // No API exists for this; the sequence is synthesised. The extended bit
        // for Delete is carried inside RDP_SCANCODE_DELETE itself.
        const UINT32 control = RDP_SCANCODE_LCONTROL;
        const UINT32 alt = RDP_SCANCODE_LMENU;
        const UINT32 del = RDP_SCANCODE_DELETE;

        freerdp_input_send_keyboard_event_ex(input, TRUE, FALSE, control);
        freerdp_input_send_keyboard_event_ex(input, TRUE, FALSE, alt);
        freerdp_input_send_keyboard_event_ex(input, TRUE, FALSE, del);
        freerdp_input_send_keyboard_event_ex(input, FALSE, FALSE, del);
        freerdp_input_send_keyboard_event_ex(input, FALSE, FALSE, alt);
        freerdp_input_send_keyboard_event_ex(input, FALSE, FALSE, control);
        break;
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Event helpers
// ---------------------------------------------------------------------------

void RdpSession::EmitState(int32_t state, const char* message) {
  rdc::EmitState(state, message);
}

void RdpSession::EmitError(int32_t code, const char* message) {
  rdc::EmitError(code, message);
}

void RdpSession::EmitFreeRdpError(void* instance_ptr, const char* stage) {
  freerdp* instance = static_cast<freerdp*>(instance_ptr);

  const UINT32 code = freerdp_get_last_error(instance->context);
  const char* description = freerdp_get_last_error_string(code);

  /* Classified here rather than handing FreeRDP's own code to the application.
   *
   * Those values are an implementation detail of the library: an upgrade could
   * renumber them, and an application that had hard-coded the numbers would go
   * on compiling while quietly mapping wrong errors to wrong sentences. A small
   * stable set of categories belongs to this bridge, and the library's own
   * description rides along in the message for whoever needs the detail. */
  int32_t category = RDC_ERR_CONNECT_FAILED;
  switch (code) {
    case FREERDP_ERROR_SUCCESS:
      description = "no error reported by the protocol stack";
      break;

    case FREERDP_ERROR_AUTHENTICATION_FAILED:
    case FREERDP_ERROR_CONNECT_ACCESS_DENIED:
    case FREERDP_ERROR_CONNECT_LOGON_FAILURE:
    case FREERDP_ERROR_CONNECT_LOGON_TYPE_NOT_GRANTED:
    case FREERDP_ERROR_CONNECT_WRONG_PASSWORD:
    case FREERDP_ERROR_INSUFFICIENT_PRIVILEGES:
    case FREERDP_ERROR_SERVER_DENIED_CONNECTION:
    case FREERDP_ERROR_SERVER_FRESH_CREDENTIALS_REQUIRED:
    case FREERDP_ERROR_SERVER_INSUFFICIENT_PRIVILEGES:
      category = RDC_ERR_AUTH_FAILED;
      break;

    /* Kept apart from a plain rejection because the advice differs: telling
     * someone their password is wrong sends them to re-type something that is
     * already correct. These say the account needs attention instead. */
    case FREERDP_ERROR_CONNECT_PASSWORD_EXPIRED:
    case FREERDP_ERROR_CONNECT_PASSWORD_CERTAINLY_EXPIRED:
    case FREERDP_ERROR_CONNECT_PASSWORD_MUST_CHANGE:
      category = RDC_ERR_PASSWORD_EXPIRED;
      break;

    case FREERDP_ERROR_CONNECT_NO_OR_MISSING_CREDENTIALS:
      category = RDC_ERR_NO_CREDENTIALS;
      break;

    case FREERDP_ERROR_TLS_CONNECT_FAILED:
      category = RDC_ERR_TLS_FAILED;
      break;

    default:
      // Everything else is a failure to establish the session: name resolution,
      // the transport, MCS, or negotiation. They are worth distinguishing in a
      // log but not in what the user is told, which is that the computer could
      // not be reached.
      break;
  }

  EmitError(category,
            TempMessage("%s: %s", stage, description != nullptr ? description : "(no description)"));
}

}  // namespace rdc
