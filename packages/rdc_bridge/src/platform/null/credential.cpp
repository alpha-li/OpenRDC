// Credential storage where the platform keeps no secrets.
//
// Every entry point reports RDC_ERR_NOT_IMPLEMENTED rather than pretending to
// succeed: the application reads that as "this build cannot hold a password"
// and asks for it on each connection, which is a worse experience but an
// honest one. A store that silently dropped the password would look like a
// wrong one the next time round.

#include "rdc_api.h"
#include "platform/platform.h"

namespace rdc {

int32_t CredentialStore(const char* credential_id, const char* password) {
  (void)credential_id;
  (void)password;
  return RDC_ERR_NOT_IMPLEMENTED;
}

int32_t CredentialLoad(const char* credential_id, char* out, int32_t capacity) {
  (void)credential_id;
  (void)out;
  (void)capacity;
  return RDC_ERR_NOT_IMPLEMENTED;
}

int32_t CredentialSize(const char* credential_id) {
  (void)credential_id;
  return RDC_ERR_NOT_IMPLEMENTED;
}

int32_t CredentialDelete(const char* credential_id) {
  (void)credential_id;
  return RDC_ERR_NOT_IMPLEMENTED;
}

}  // namespace rdc
