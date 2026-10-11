/// Fallback engine for platforms without the native bridge (web, and any
/// platform the plugin is not built for).
///
/// This file must not import `dart:ffi` or `dart:io`: it is what the web
/// compiler resolves to when `dart.library.ffi` is false.
library;

import 'dart:async';

import 'rdc_engine.dart';

/// Selected by the conditional import in rdc_engine.dart.
RdcEngine createRdcEngine() => const _UnsupportedEngine();

class _UnsupportedEngine implements RdcEngine {
  const _UnsupportedEngine();

  @override
  bool get isAvailable => false;

  @override
  String get backendName => '不可用';

  @override
  int get textureId => -1;

  @override
  Stream<RdcEngineEvent> get events => const Stream<RdcEngineEvent>.empty();

  @override
  void connect(RdcConnectionRequest request) {
    throw RdcEngineException(
      RdcEngineError.unavailable,
      'no engine on this platform',
    );
  }

  @override
  int startTestPattern({required int width, required int height}) {
    throw RdcEngineException(
      RdcEngineError.unavailable,
      'no engine on this platform',
    );
  }

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
  bool get isCredentialStorePersistent => false;

  @override
  Future<bool> storeCredential(String credentialId, String password) async =>
      false;

  @override
  Future<String?> loadCredential(String credentialId) async => null;

  @override
  Future<void> deleteCredential(String credentialId) async {}

  @override
  Future<void> dispose() async {}
}
