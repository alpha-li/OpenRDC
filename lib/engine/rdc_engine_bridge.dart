/// The real engine, backed by the native library through `dart:ffi`.
///
/// This is the only file in the application that touches `dart:ffi`. It is
/// selected by the conditional import in rdc_engine.dart, so the UI layer stays
/// free of native types and the web build never sees them.
library;

import 'dart:async';

// RdcCursorKind is hidden on purpose: the engine has an enum of its own by that
// name, which is what the application sees, and the bridge's constants are only
// needed for the values on the cursor it returns.
import 'package:rdc_bridge/rdc_bridge.dart' hide RdcCursorKind;

import 'rdc_engine.dart';

/// Selected by the conditional import in rdc_engine.dart.
RdcEngine createRdcEngine() => RdcBridgeEngine();

class RdcBridgeEngine implements RdcEngine {
  RdcBridgeEngine() {
    try {
      _bridge = RdcBridge.instance;
      _bridge.setEventSink(_handleNativeEvent);
      _available = true;
    } on RdcUnavailableException {
      // Left unavailable; isAvailable reports it and startTestPattern throws a
      // readable message rather than the raw loader error.
      _available = false;
    }
  }

  late final RdcBridge _bridge;
  final StreamController<RdcEngineEvent> _events =
      StreamController<RdcEngineEvent>.broadcast();

  bool _available = false;
  bool _disposed = false;

  @override
  bool get isAvailable => _available;

  @override
  String get backendName => _available ? _bridge.version : '不可用';

  @override
  int get textureId => _available ? _bridge.textureId : -1;

  @override
  Stream<RdcEngineEvent> get events => _events.stream;

  @override
  void connect(RdcConnectionRequest request) {
    _ensureUsable();
    _bridge.connect(
      RdcConnectParams(
        hostname: request.hostname,
        port: request.port,
        username: request.username,
        password: request.password,
        domain: request.domain,
        desktopWidth: request.desktopWidth,
        desktopHeight: request.desktopHeight,
        colorDepth: request.colorDepth,
        adminSession: request.adminSession,
        ignoreCertificate: request.ignoreCertificate,
        reconnectIfDropped: request.reconnectIfDropped,
        audioPlayback: request.audioPlayback,
        useMultiMonitor: request.useMultiMonitor,
        folders: [
          for (final folder in request.folders)
            RdcRedirectedFolderParams(path: folder.path, name: folder.name),
        ],
        redirectAllDrives: request.redirectAllDrives,
        gateway: switch (request.gateway) {
          null => null,
          final gateway => RdcGatewayParams(
            hostname: gateway.hostname,
            port: gateway.port,
            username: gateway.username,
            password: gateway.password,
            domain: gateway.domain,
            bypassForLocalAddresses: gateway.bypassForLocalAddresses,
          ),
        },
      ),
    );
  }

  @override
  int startTestPattern({required int width, required int height}) {
    _ensureUsable();
    return _bridge.startTestPattern(width: width, height: height);
  }

  @override
  void stop() {
    if (!_available) {
      return;
    }
    // Either producer may be running; both calls are no-ops when theirs is not.
    _bridge.stopTestPattern();
    _bridge.disconnect();
  }

  @override
  RdcFrame? captureFrame() {
    if (!_available) {
      return null;
    }
    final frame = _bridge.captureFrame();
    if (frame == null) {
      return null;
    }
    return RdcFrame(
      width: frame.$1,
      height: frame.$2,
      pixels: frame.$3,
    );
  }

  @override
  void sendMouse(int action, int x, int y, {int wheelDelta = 0}) {
    if (_available) {
      _bridge.sendMouse(action, x, y, wheelDelta: wheelDelta);
    }
  }

  @override
  void sendKey({
    required int scancode,
    required bool down,
    bool extended = false,
  }) {
    if (_available) {
      _bridge.sendKey(scancode: scancode, down: down, extended: extended);
    }
  }

  @override
  void sendText(String text) {
    if (_available) {
      _bridge.sendText(text);
    }
  }

  @override
  void sendCtrlAltDel() {
    if (_available) {
      _bridge.sendCtrlAltDel();
    }
  }

  @override
  void setKeyboardCapture(bool enabled) {
    if (_available) {
      _bridge.setKeyboardCapture(enabled);
    }
  }

  @override
  void respondToCertificate(int decision) {
    if (_available) {
      _bridge.respondToCertificate(decision);
    }
  }

  @override
  void setLocalClipboardText(String text) {
    if (_available) {
      _bridge.setLocalClipboardText(text);
    }
  }

  @override
  void runWindowCommand(int command) {
    if (_available) {
      _bridge.windowCommand(command);
    }
  }

  @override
  bool get isFullScreen => _available && _bridge.isFullScreen;

  @override
  void resizeDesktop(int width, int height) {
    if (_available) {
      _bridge.resizeDesktop(width, height);
    }
  }

  @override
  bool get isCredentialStorePersistent => _available;

  @override
  Future<bool> storeCredential(String credentialId, String password) async {
    if (!_available) {
      return false;
    }
    return _bridge.storeCredential(credentialId, password) == RdcResult.ok;
  }

  @override
  Future<String?> loadCredential(String credentialId) async {
    if (!_available) {
      return null;
    }
    return _bridge.loadCredential(credentialId);
  }

  @override
  Future<void> deleteCredential(String credentialId) async {
    if (_available) {
      _bridge.deleteCredential(credentialId);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (_available) {
      _bridge.stopTestPattern();
      // The session too, not only the test pattern: a page can be torn down
      // without ever having asked to stop, and a worker that finished on its own
      // stays unjoined until somebody reaps it -- which is what makes the *next*
      // connection abort the process. Before the sink is cleared, so the reap
      // cannot be followed by a callback into a stream that is about to close.
      _bridge.disconnect();
      _bridge.setEventSink(null);
    }
    await _events.close();
  }

  void _ensureUsable() {
    if (!_available) {
      throw RdcEngineException(
        RdcEngineError.unavailable,
        'the native library could not be loaded',
      );
    }
    if (_disposed) {
      throw RdcEngineException(RdcEngineError.disposed);
    }
  }

  /// Called from whichever native thread raised the event; `NativeCallable
  /// .listener` marshals it onto this isolate's event loop before we run.
  void _handleNativeEvent(RdcEvent event) {
    if (_disposed || _events.isClosed) {
      return;
    }
    switch (event.kind) {
      case RdcEventKind.state:
        _events.add(RdcStatusEvent(RdcSessionStatus.fromNative(event.code)));
      case RdcEventKind.desktopSize:
        final size = event.desktopSize;
        if (size != null) {
          _events.add(RdcDesktopSizeEvent(RdcDesktopSize(size.$1, size.$2)));
        }
      case RdcEventKind.error:
        _events.add(RdcErrorEvent(code: event.code, message: event.message));
      case RdcEventKind.cursor:
        final cursor = _bridge.currentCursor();
        if (cursor != null) {
          _events.add(
            RdcCursorEvent(
              RdcCursorShape(
                kind: RdcCursorKind.values[cursor.kind],
                width: cursor.width,
                height: cursor.height,
                hotspotX: cursor.hotspotX,
                hotspotY: cursor.hotspotY,
                pixels: cursor.pixels,
              ),
            ),
          );
        }
      case RdcEventKind.clipboard:
        final text = _bridge.takeRemoteClipboardText();
        if (text != null && text.isNotEmpty) {
          _events.add(RdcClipboardEvent(text));
        }
      case RdcEventKind.certificate:
        // The details are read back rather than carried in the event: the event
        // only says that a decision is wanted, and by the time it is handled the
        // prompt may already have timed out, in which case there is nothing to
        // read and no point raising it.
        final pending = _bridge.pendingCertificate();
        if (pending != null) {
          _events.add(
            RdcCertificateEvent(
              RdcCertificate(
                host: pending.host,
                port: pending.port,
                commonName: pending.commonName,
                subject: pending.subject,
                issuer: pending.issuer,
                fingerprint: pending.fingerprint,
                changed: pending.changed,
                nameMismatch: pending.nameMismatch,
                oldFingerprint: pending.oldFingerprint,
              ),
            ),
          );
        }
    }
  }
}
