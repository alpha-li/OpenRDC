// Password storage backed by the operating system's secret store.
//
// On Windows that is Credential Manager, reached through CredWriteW and
// friends. The alternative -- a file the application encrypts itself -- would
// mean inventing a key, deciding where to keep the key, and getting the
// encryption right; the platform already does all of that, ties access to the
// logged-in user, and lets the user see and revoke entries in their own
// credential UI.
//
// Entries are generic credentials under a namespaced target name, so they are
// recognisable in that UI and cannot collide with anything else's.

#include "rdc_api.h"

#include "rdc_core.h"

#include <cstring>
#include <string>

#ifdef _WIN32
#include <windows.h>
#include <wincred.h>

#include <vector>
#endif

namespace rdc {
namespace {

#ifdef _WIN32

/// Prefixes the caller's id so entries are identifiable as ours.
///
/// Credential Manager target names are a flat namespace shared with everything
/// else on the machine, so an unprefixed id like "cred-1" would be unwise.
std::wstring TargetName(const std::string& credential_id) {
  std::wstring target = L"OpenRDC/";
  // The ids are ASCII by construction, so a byte-wise widening is exact and
  // avoids dragging in a conversion call.
  target.append(credential_id.begin(), credential_id.end());
  return target;
}

/// UTF-8 to the UTF-16LE that Credential Manager expects.
///
/// The blob is nominally arbitrary bytes, but the convention on Windows -- what
/// cmdkey, mstsc and everything else use -- is UTF-16LE. Storing UTF-8 would
/// work for this application alone and break the moment anything else reads or
/// writes the same entry, which is a trap worth not walking into: it is the
/// reason a credential written by cmdkey was not readable back correctly.
std::vector<BYTE> ToCredentialBlob(const char* utf8) {
  const int wide_length = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, nullptr, 0);
  if (wide_length <= 1) {
    // Empty, or a conversion failure; either way there is nothing to store.
    return std::vector<BYTE>();
  }

  std::vector<wchar_t> wide(static_cast<size_t>(wide_length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8, -1, wide.data(), wide_length);

  // Drop the terminator: the blob length carries the extent, and storing the
  // terminator would make the round trip asymmetric.
  const size_t characters = static_cast<size_t>(wide_length - 1);
  std::vector<BYTE> blob(characters * sizeof(wchar_t));
  if (characters > 0) {
    std::memcpy(blob.data(), wide.data(), characters * sizeof(wchar_t));
  }
  return blob;
}

/// The inverse of ToCredentialBlob, into a NUL-terminated UTF-8 string.
bool FromCredentialBlob(const BYTE* blob, DWORD length, std::string* out) {
  if (blob == nullptr || length == 0) {
    out->clear();
    return true;
  }
  if (length % sizeof(wchar_t) != 0) {
    // Not a UTF-16 blob. Rather than guess, refuse: a caller that stored
    // something else should not get a silently mangled password.
    return false;
  }

  const int characters = static_cast<int>(length / sizeof(wchar_t));
  const int utf8_length =
      WideCharToMultiByte(CP_UTF8, 0, reinterpret_cast<const wchar_t*>(blob), characters, nullptr,
                          0, nullptr, nullptr);
  if (utf8_length <= 0) {
    out->clear();
    return true;
  }

  out->resize(static_cast<size_t>(utf8_length));
  WideCharToMultiByte(CP_UTF8, 0, reinterpret_cast<const wchar_t*>(blob), characters, out->data(),
                      utf8_length, nullptr, nullptr);
  return true;
}

#endif  // _WIN32

}  // namespace

int32_t CredentialStore(const char* credential_id, const char* password) {
#ifdef _WIN32
  if (credential_id == nullptr || credential_id[0] == '\0' || password == nullptr) {
    return RDC_ERR_BAD_ARGUMENT;
  }

  const std::wstring target = TargetName(credential_id);
  std::vector<BYTE> blob = ToCredentialBlob(password);
  if (blob.empty()) {
    return RDC_ERR_BAD_ARGUMENT;
  }

  CREDENTIALW credential = {};
  credential.Type = CRED_TYPE_GENERIC;
  credential.TargetName = const_cast<LPWSTR>(target.c_str());
  credential.CredentialBlobSize = static_cast<DWORD>(blob.size());
  credential.CredentialBlob = blob.data();
  // Local machine rather than session: the point of saving a password is that
  // it survives a restart.
  credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
  credential.UserName = const_cast<LPWSTR>(target.c_str());

  if (!CredWriteW(&credential, 0)) {
    Log("credential: CredWrite failed with %lu", GetLastError());
    return RDC_ERR_PLATFORM;
  }
  return RDC_OK;
#else
  (void)credential_id;
  (void)password;
  return RDC_ERR_NOT_IMPLEMENTED;
#endif
}

int32_t CredentialSize(const char* credential_id) {
#ifdef _WIN32
  if (credential_id == nullptr || credential_id[0] == '\0') {
    return 0;
  }

  const std::wstring target = TargetName(credential_id);
  PCREDENTIALW credential = nullptr;
  if (!CredReadW(target.c_str(), CRED_TYPE_GENERIC, 0, &credential)) {
    return 0;
  }

  // Worst case for a UTF-16 blob of this length: three UTF-8 bytes per code
  // unit, plus the terminator the caller is promised. Oversized on purpose --
  // the caller uses this only to allocate.
  const int32_t size =
      static_cast<int32_t>(credential->CredentialBlobSize / sizeof(wchar_t)) * 3 + 1;
  CredFree(credential);
  return size;
#else
  (void)credential_id;
  return 0;
#endif
}

int32_t CredentialLoad(const char* credential_id, char* out, int32_t capacity) {
#ifdef _WIN32
  if (credential_id == nullptr || out == nullptr || capacity <= 0) {
    return RDC_ERR_BAD_ARGUMENT;
  }

  const std::wstring target = TargetName(credential_id);
  PCREDENTIALW credential = nullptr;
  if (!CredReadW(target.c_str(), CRED_TYPE_GENERIC, 0, &credential)) {
    const DWORD error = GetLastError();
    if (error == ERROR_NOT_FOUND) {
      return RDC_ERR_NOT_FOUND;
    }
    Log("credential: CredRead failed with %lu", error);
    return RDC_ERR_PLATFORM;
  }

  std::string password;
  const bool decoded = FromCredentialBlob(credential->CredentialBlob,
                                          credential->CredentialBlobSize, &password);
  CredFree(credential);

  if (!decoded) {
    Log("credential: stored blob is not UTF-16; refusing to guess at its encoding");
    return RDC_ERR_PLATFORM;
  }
  if (static_cast<int32_t>(password.size()) + 1 > capacity) {
    return RDC_ERR_BAD_ARGUMENT;
  }

  std::memcpy(out, password.c_str(), password.size() + 1);
  return RDC_OK;
#else
  (void)credential_id;
  (void)out;
  (void)capacity;
  return RDC_ERR_NOT_IMPLEMENTED;
#endif
}

int32_t CredentialDelete(const char* credential_id) {
#ifdef _WIN32
  if (credential_id == nullptr || credential_id[0] == '\0') {
    return RDC_ERR_BAD_ARGUMENT;
  }

  const std::wstring target = TargetName(credential_id);
  if (!CredDeleteW(target.c_str(), CRED_TYPE_GENERIC, 0)) {
    const DWORD error = GetLastError();
    // Deleting something that is not there is the state the caller wanted, so
    // it is not an error.
    if (error == ERROR_NOT_FOUND) {
      return RDC_OK;
    }
    Log("credential: CredDelete failed with %lu", error);
    return RDC_ERR_PLATFORM;
  }
  return RDC_OK;
#else
  (void)credential_id;
  return RDC_ERR_NOT_IMPLEMENTED;
#endif
}

}  // namespace rdc
