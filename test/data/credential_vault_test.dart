import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openrdc/data/credential_vault.dart';
import 'package:openrdc/engine/rdc_engine.dart';

void main() {
  group('EngineCredentialVault', () {
    test('passes the id and secret straight through', () async {
      // The vault is a thin adapter, and the only thing worth pinning is that
      // it does not mangle either value on the way to the platform store --
      // a wrong id would silently orphan saved passwords.
      final engine = _FakeEngine();
      final vault = EngineCredentialVault(engine);

      await vault.store('cred-1', 'hunter2');

      expect(engine.stored, {'cred-1': 'hunter2'});
      expect(await vault.retrieve('cred-1'), 'hunter2');
    });

    test('reports persistence from the engine', () {
      expect(
        EngineCredentialVault(_FakeEngine(persistent: true)).isPersistent,
        isTrue,
      );
      expect(
        EngineCredentialVault(_FakeEngine(persistent: false)).isPersistent,
        isFalse,
      );
    });

    test('returns null for an unknown id rather than throwing', () async {
      final vault = EngineCredentialVault(_FakeEngine());
      expect(await vault.retrieve('never-stored'), isNull);
    });

    test('forwards deletion', () async {
      final engine = _FakeEngine();
      final vault = EngineCredentialVault(engine);
      await vault.store('cred-1', 'x');

      await vault.delete('cred-1');

      expect(engine.stored, isEmpty);
      expect(await vault.retrieve('cred-1'), isNull);
    });

    test('preserves non-ASCII secrets unchanged', () async {
      // The native side takes UTF-8 and the platform store is byte-oriented, so
      // anything that mangles encoding on the way through would corrupt exactly
      // the passwords least likely to be noticed in testing.
      final engine = _FakeEngine();
      final vault = EngineCredentialVault(engine);
      const secret = 'p@ss 密码 🔐';

      await vault.store('cred-1', secret);

      expect(await vault.retrieve('cred-1'), secret);
    });
  });

  group('MemoryCredentialVault', () {
    test('never claims to persist', () {
      // The UI reads this to decide whether to warn that the password is
      // session-only, so it must not overstate what it does.
      expect(MemoryCredentialVault().isPersistent, isFalse);
    });

    test('round-trips and deletes', () async {
      final vault = MemoryCredentialVault();
      await vault.store('a', 'one');
      expect(await vault.retrieve('a'), 'one');

      await vault.delete('a');
      expect(await vault.retrieve('a'), isNull);
    });
  });
}

/// A stand-in engine that keeps credentials in a map, so the adapter can be
/// tested without the native library.
class _FakeEngine implements RdcEngine {
  _FakeEngine({this.persistent = true});

  final bool persistent;
  final Map<String, String> stored = {};

  @override
  bool get isCredentialStorePersistent => persistent;

  @override
  Future<bool> storeCredential(String credentialId, String password) async {
    if (!persistent) {
      return false;
    }
    stored[credentialId] = password;
    return true;
  }

  @override
  Future<String?> loadCredential(String credentialId) async =>
      persistent ? stored[credentialId] : null;

  @override
  Future<void> deleteCredential(String credentialId) async {
    stored.remove(credentialId);
  }

  // --- unused by these tests -------------------------------------------------

  @override
  bool get isAvailable => persistent;

  @override
  String get backendName => 'fake';

  @override
  int get textureId => -1;

  @override
  Stream<RdcEngineEvent> get events => const Stream<RdcEngineEvent>.empty();

  @override
  void connect(RdcConnectionRequest request) {}

  @override
  int startTestPattern({required int width, required int height}) => 0;

  @override
  void stop() {}

  @override
  RdcFrame? captureFrame() => null;

  @override
  void sendMouse(int action, int x, int y, {int wheelDelta = 0}) {}

  @override
  void sendKey({
    required int scancode,
    required bool down,
    bool extended = false,
  }) {}

  @override
  void sendText(String text) {}

  @override
  void sendCtrlAltDel() {}

  @override
  void setKeyboardCapture(bool enabled) {}

  @override
  void respondToCertificate(int decision) {}

  @override
  void setLocalClipboardText(String text) {}

  @override
  void runWindowCommand(int command) {}

  @override
  bool get isFullScreen => false;

  @override
  void resizeDesktop(int width, int height) {}

  @override
  Future<void> dispose() async {}
}
