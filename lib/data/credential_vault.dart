/// Storage for RDP passwords.
///
/// Passwords never go into the connection file. They live in the platform's own
/// secret store, keyed by credential id, and are read back only at the moment a
/// session is established.
///
/// [EngineCredentialVault] is the real one: it goes through the native bridge to
/// the operating system's secret store, which on Windows means Credential
/// Manager. [MemoryCredentialVault] is the fallback for tests and for platforms
/// that have no such store; it reports [CredentialVault.isPersistent] false so
/// the UI says so rather than implying the password was saved.
library;

import '../engine/rdc_engine.dart';

/// A place to keep secrets.
abstract class CredentialVault {
  /// Persists [password] for [credentialId], replacing any previous value.
  Future<void> store(String credentialId, String password);

  /// The stored password, or null when there is none.
  Future<String?> retrieve(String credentialId);

  Future<void> delete(String credentialId);

  /// Whether secrets survive the process. Drives what the UI promises.
  bool get isPersistent;
}

/// The real vault: passwords go to the operating system's secret store through
/// the native bridge.
///
/// It lives here rather than in the engine layer because the engine is about
/// the protocol, and this is about persistence. The dependency runs the other
/// way — this adapter takes an engine, so the engine stays unaware of it.
class EngineCredentialVault implements CredentialVault {
  EngineCredentialVault(this._engine);

  final RdcEngine _engine;

  @override
  bool get isPersistent => _engine.isCredentialStorePersistent;

  @override
  Future<void> store(String credentialId, String password) =>
      _engine.storeCredential(credentialId, password);

  @override
  Future<String?> retrieve(String credentialId) =>
      _engine.loadCredential(credentialId);

  @override
  Future<void> delete(String credentialId) =>
      _engine.deleteCredential(credentialId);
}

/// Session-lifetime-only vault, for tests and for platforms with no secret
/// store.
///
/// This is not a security boundary: the passwords sit in the Dart heap in plain
/// text. [isPersistent] reports false so the UI can say so rather than implying
/// they were saved.
class MemoryCredentialVault implements CredentialVault {
  final Map<String, String> _secrets = {};

  @override
  bool get isPersistent => false;

  @override
  Future<void> store(String credentialId, String password) async {
    _secrets[credentialId] = password;
  }

  @override
  Future<String?> retrieve(String credentialId) async => _secrets[credentialId];

  @override
  Future<void> delete(String credentialId) async {
    _secrets.remove(credentialId);
  }
}
