// Fallback implementation of RdpSession for platforms built without FreeRDP.
//
// It exists so the shared library keeps exporting the complete ABI and a
// caller gets a diagnosable error rather than a missing-symbol crash. The frame
// ring and the test pattern are unaffected, so the rest of the pipeline can
// still be exercised without the protocol stack.

#include "rdc_session.h"

#include "rdc_core.h"

namespace rdc {

RdpSession& RdpSession::Instance() {
  static RdpSession session;
  return session;
}

RdpSession::~RdpSession() {}

int32_t RdpSession::Connect(const rdc_connect_params& params) {
  (void)params;
  EmitError(RDC_ERR_NOT_IMPLEMENTED,
            "此构建未包含 FreeRDP，无法建立远程桌面连接。");
  EmitState(RDC_STATE_FAILED, nullptr);
  return RDC_ERR_NOT_IMPLEMENTED;
}

void RdpSession::Disconnect() {}

void RdpSession::AddRedirectedFolder(const std::string& name, const std::string& path) {
  (void)name;
  (void)path;
}

void RdpSession::SetRedirectAllDrives(bool enabled) { (void)enabled; }

void RdpSession::QueueResize(int32_t width, int32_t height) {
  (void)width;
  (void)height;
}

void RdpSession::DrainResize() {}

void RdpSession::RespondToCertificate(int32_t decision) { (void)decision; }

int32_t RdpSession::GetPendingCertificate(rdc_certificate_info* out) {
  (void)out;
  return RDC_ERR_BAD_ARGUMENT;
}

int32_t RdpSession::RequestCertificateDecision(const CertificateDetails& details) {
  (void)details;
  return RDC_CERT_REJECT;
}

void RdpSession::QueueMouse(int32_t action, int32_t x, int32_t y, int32_t wheel_delta) {
  (void)action;
  (void)x;
  (void)y;
  (void)wheel_delta;
}

void RdpSession::QueueKey(int32_t scancode, int32_t down, int32_t extended) {
  (void)scancode;
  (void)down;
  (void)extended;
}

void RdpSession::QueueText(const uint16_t* code_units, int32_t length) {
  (void)code_units;
  (void)length;
}

void RdpSession::QueueCtrlAltDel() {}

int RdpSession::OnClientNew(void* instance, void* context) {
  (void)instance;
  (void)context;
  return 0;
}

void RdpSession::OnClientFree() {}

bool RdpSession::OnPreConnect(void* instance) {
  (void)instance;
  return false;
}

bool RdpSession::OnPostConnect(void* instance) {
  (void)instance;
  return false;
}

void RdpSession::OnPostDisconnect() {}

bool RdpSession::OnEndPaint() { return false; }

bool RdpSession::OnDesktopResize() { return false; }

uint32_t RdpSession::OnVerifyCertificate(const char* host, uint16_t port, const char* common_name,
                                         const char* subject, const char* issuer,
                                         const char* fingerprint, uint32_t flags) {
  (void)host;
  (void)port;
  (void)common_name;
  (void)subject;
  (void)issuer;
  (void)fingerprint;
  (void)flags;
  return 0;
}

uint32_t RdpSession::OnVerifyChangedCertificate(const char* host, uint16_t port,
                                                const char* common_name, const char* subject,
                                                const char* issuer, const char* new_fingerprint,
                                                const char* old_subject, const char* old_issuer,
                                                const char* old_fingerprint, uint32_t flags) {
  (void)host;
  (void)port;
  (void)common_name;
  (void)subject;
  (void)issuer;
  (void)new_fingerprint;
  (void)old_subject;
  (void)old_issuer;
  (void)old_fingerprint;
  (void)flags;
  return 0;
}

bool RdpSession::OnAuthenticate(char** username, char** password, char** domain) {
  (void)username;
  (void)password;
  (void)domain;
  return false;
}

void RdpSession::WorkerMain() {}

void RdpSession::RunSession() {}

void RdpSession::RunEventLoop() {}

void RdpSession::DrainInput() {}

void RdpSession::PublishFrame() {}

void RdpSession::EmitState(int32_t state, const char* message) {
  rdc::EmitState(state, message);
}

void RdpSession::EmitError(int32_t code, const char* message) {
  rdc::EmitError(code, message);
}

void RdpSession::EmitFreeRdpError(void* instance, const char* stage) {
  (void)instance;
  (void)stage;
}

}  // namespace rdc
