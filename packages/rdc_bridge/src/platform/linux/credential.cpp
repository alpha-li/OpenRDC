// Credential storage on Linux, through the Secret Service.
//
// The Secret Service is the D-Bus interface that GNOME Keyring and KWallet both
// implement, and libsecret is its client. Passwords go there rather than to a
// file this application writes, for the same reason they go to the Credential
// Manager on Windows: a password in a file we own is a password in a file we
// have to protect, and that is a problem already solved.
//
// Where no provider is running -- a bare container, a minimal session -- every
// call fails, the application reads that as "this build cannot hold a password",
// and it asks on each connection. That is the same answer platform/null gives
// outright, arrived at by trying instead of by assuming.

#include "platform/platform.h"

#include <libsecret/secret.h>

#include <cstring>

#include "rdc_api.h"
#include "rdc_core.h"

namespace rdc {
namespace {

/// Names our entries. The store is shared with everything else on the machine,
/// so the schema name is what keeps "cred-1" from colliding with someone else's
/// idea of the same id.
const SecretSchema* RdcSchema() {
  static const SecretSchema schema = {
      "org.openrdc.Credential",
      SECRET_SCHEMA_NONE,
      {
          {"id", SECRET_SCHEMA_ATTRIBUTE_STRING},
          {nullptr, SECRET_SCHEMA_ATTRIBUTE_STRING},
      },
      // The struct's trailing fields are reserved for libsecret's own use.
      // Spelled out rather than left to zero-filling so the build stays free of
      // -Wmissing-field-initializers, which is otherwise the only thing anyone
      // reads in this log.
      0,
      nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr,
  };
  return &schema;
}

void LogLookupError(const char* what, GError* error) {
  if (error != nullptr) {
    Log("credential: %s failed: %s", what, error->message);
    g_error_free(error);
  } else {
    Log("credential: %s failed", what);
  }
}

}  // namespace

int32_t CredentialStore(const char* credential_id, const char* password) {
  if (credential_id == nullptr || credential_id[0] == '\0' || password == nullptr) {
    return RDC_ERR_BAD_ARGUMENT;
  }

  GError* error = nullptr;
  const gboolean stored = secret_password_store_sync(
      RdcSchema(), SECRET_COLLECTION_DEFAULT, "OpenRDC remote desktop password",
      password, nullptr, &error, "id", credential_id, nullptr);
  if (!stored) {
    LogLookupError("storing", error);
    return RDC_ERR_PLATFORM;
  }
  return RDC_OK;
}

int32_t CredentialSize(const char* credential_id) {
  if (credential_id == nullptr || credential_id[0] == '\0') {
    return 0;
  }

  GError* error = nullptr;
  gchar* password = secret_password_lookup_sync(
      RdcSchema(), nullptr, &error, "id", credential_id, nullptr);
  if (error != nullptr) {
    LogLookupError("looking up", error);
    return 0;
  }
  if (password == nullptr) {
    return 0;
  }

  // Stored as UTF-8, unlike the UTF-16 blob the Credential Manager insists on,
  // so the length is exact rather than the Windows side's worst-case estimate.
  const int32_t size = static_cast<int32_t>(std::strlen(password)) + 1;
  secret_password_free(password);
  return size;
}

int32_t CredentialLoad(const char* credential_id, char* out, int32_t capacity) {
  if (credential_id == nullptr || credential_id[0] == '\0' || out == nullptr ||
      capacity <= 0) {
    return RDC_ERR_BAD_ARGUMENT;
  }

  GError* error = nullptr;
  gchar* password = secret_password_lookup_sync(
      RdcSchema(), nullptr, &error, "id", credential_id, nullptr);
  if (error != nullptr) {
    LogLookupError("looking up", error);
    return RDC_ERR_PLATFORM;
  }
  if (password == nullptr) {
    return RDC_ERR_NOT_FOUND;
  }

  const size_t length = std::strlen(password);
  if (static_cast<int32_t>(length) + 1 > capacity) {
    secret_password_free(password);
    return RDC_ERR_BAD_ARGUMENT;
  }

  std::memcpy(out, password, length + 1);
  secret_password_free(password);
  return RDC_OK;
}

int32_t CredentialDelete(const char* credential_id) {
  if (credential_id == nullptr || credential_id[0] == '\0') {
    return RDC_ERR_BAD_ARGUMENT;
  }

  GError* error = nullptr;
  const gboolean cleared = secret_password_clear_sync(
      RdcSchema(), nullptr, &error, "id", credential_id, nullptr);
  if (!cleared) {
    // Deleting what is not there is the state the caller wanted, so this is not
    // treated as a failure -- the same rule the Windows implementation follows.
    LogLookupError("deleting", error);
  }
  return RDC_OK;
}

}  // namespace rdc
