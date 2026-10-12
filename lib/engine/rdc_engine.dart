/// Platform-neutral front door to the remote desktop engine.
///
/// Everything that touches `dart:ffi` lives behind this interface, and only in
/// the implementation selected below. The UI layer imports this file and never
/// sees a pointer, which keeps the whole presentation layer testable with the
/// stub and keeps the web target compiling even though the native library
/// cannot exist there.
library;

import 'dart:typed_data';

import 'rdc_engine_stub.dart' if (dart.library.ffi) 'rdc_engine_bridge.dart';

/// Why the engine cannot be used.
enum RdcEngineError {
  /// No native library for this platform, or it could not be loaded.
  unavailable,

  /// The engine has been disposed and cannot be used again.
  disposed,
}

/// Raised when the engine is asked to do something it cannot.
///
/// Typed rather than carrying a sentence: a sentence from this layer would
/// arrive untranslatable and in whatever language the layer happened to use.
/// The kind crosses the boundary; the wording is chosen where it is shown.
class RdcEngineException implements Exception {
  RdcEngineException(this.kind, [this.detail]);

  final RdcEngineError kind;

  /// Developer-facing detail, or null. Never shown in place of the kind's own
  /// wording — only alongside it, for diagnosis.
  final String? detail;

  @override
  String toString() => 'RdcEngineException: ${kind.name}';
}

/// Lifecycle of a session, mirroring `RDC_STATE_*` in `src/rdc_api.h`.
enum RdcSessionStatus {
  idle,
  connecting,
  authenticating,
  connected,
  disconnecting,
  disconnected,
  failed;

  /// True once the session has stopped and will not resume on its own. The
  /// labels for these states live in `l10n/engine_labels.dart`, since an enum
  /// cannot reach a BuildContext and the words need translating.
  bool get isTerminal => this == disconnected || this == failed || this == idle;

  static RdcSessionStatus fromNative(int value) =>
      value >= 0 && value < RdcSessionStatus.values.length
      ? RdcSessionStatus.values[value]
      : RdcSessionStatus.failed;
}

/// Desktop geometry reported by the remote host.
class RdcDesktopSize {
  const RdcDesktopSize(this.width, this.height);

  final int width;
  final int height;

  double get aspectRatio => height == 0 ? 1 : width / height;

  @override
  bool operator ==(Object other) =>
      other is RdcDesktopSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => '$width×$height';
}

/// Something the engine wants the UI to know about.
sealed class RdcEngineEvent {
  const RdcEngineEvent();
}

/// The session moved to a new lifecycle state.
class RdcStatusEvent extends RdcEngineEvent {
  const RdcStatusEvent(this.status);

  final RdcSessionStatus status;

  @override
  String toString() => 'RdcStatusEvent($status)';
}

/// The remote desktop changed size, e.g. after a resolution change.
class RdcDesktopSizeEvent extends RdcEngineEvent {
  const RdcDesktopSizeEvent(this.size);

  final RdcDesktopSize size;

  @override
  String toString() => 'RdcDesktopSizeEvent($size)';
}

/// The host presented a certificate that needs a decision before the connection
/// can continue. The engine is blocked until [RdcEngine.respondToCertificate]
/// is called.
class RdcCertificateEvent extends RdcEngineEvent {
  const RdcCertificateEvent(this.certificate);

  final RdcCertificate certificate;

  @override
  String toString() => 'RdcCertificateEvent(${certificate.host})';
}

/// What the user decided about a certificate.
abstract final class RdcCertificateDecision {
  /// Abandon the connection.
  static const int reject = 0;

  /// Accept and remember, so the same host is not asked about again.
  static const int acceptAndStore = 1;

  /// Accept for this connection only.
  static const int acceptOnce = 2;
}

/// Details of a certificate awaiting approval.
class RdcCertificate {
  const RdcCertificate({
    required this.host,
    required this.port,
    required this.commonName,
    required this.subject,
    required this.issuer,
    required this.fingerprint,
    required this.changed,
    required this.nameMismatch,
    required this.oldFingerprint,
  });

  final String host;
  final int port;

  /// The name the certificate was issued for. Empty when it carries none, which
  /// is common for the self-signed certificates workgroup machines generate.
  final String commonName;

  final String subject;
  final String issuer;

  /// SHA-256, colon-separated, as FreeRDP reports it.
  final String fingerprint;

  /// True when this differs from the certificate previously accepted for this
  /// host. A first-time self-signed certificate is routine; a *changed* one is
  /// what an interception attempt looks like, and the dialog says so.
  final bool changed;

  /// True when the name in the certificate is not the host being connected to.
  /// A different problem from [changed], and the dialog describes it
  /// differently: a re-addressed server produces this on its own, while a
  /// changed certificate usually means someone is in the middle.
  final bool nameMismatch;

  final String oldFingerprint;
}

/// Text has arrived from the remote machine's clipboard and should be placed on
/// the local one. Delivery is "fire and collect": the text is taken once, and
/// it is gone afterwards.
class RdcClipboardEvent extends RdcEngineEvent {
  const RdcClipboardEvent(this.text);

  final String text;

  @override
  String toString() => 'RdcClipboardEvent(${text.length} chars)';
}

/// What the remote machine's pointer is.
///
/// Values mirror `RDC_CURSOR_*` in `src/rdc_api.h` and are passed straight
/// through, so the two lists are pinned together by a test rather than by
/// memory.
enum RdcCursorKind {
  /// The remote machine is asking for the ordinary arrow, which is the local
  /// one: there is no picture to draw.
  defaultArrow,

  /// The remote machine has hidden the pointer, e.g. while playing a video.
  hidden,

  /// A picture, in [RdcCursorShape.pixels].
  image,
}

/// The remote machine's mouse pointer.
///
/// RDP carries cursors as pictures rather than as named shapes, so anything
/// other than the ordinary arrow arrives as pixels to draw. Flutter has no API
/// for a bitmap cursor, which is why this is an image and not a `MouseCursor`.
class RdcCursorShape {
  const RdcCursorShape({
    required this.kind,
    this.width = 0,
    this.height = 0,
    this.hotspotX = 0,
    this.hotspotY = 0,
    this.pixels,
  });

  final RdcCursorKind kind;

  final int width;
  final int height;

  /// The point in the picture that belongs under the pointer.
  final int hotspotX;
  final int hotspotY;

  /// RGBA, row by row from the top. Null unless [kind] is [RdcCursorKind.image].
  final Uint8List? pixels;

  @override
  String toString() =>
      'RdcCursorShape(${kind.name}, ${width}x$height, hotspot: $hotspotX,$hotspotY)';
}

/// The remote machine's pointer changed shape. Read the shape itself from the
/// event: a later change may already have replaced it.
class RdcCursorEvent extends RdcEngineEvent {
  const RdcCursorEvent(this.cursor);

  final RdcCursorShape cursor;

  @override
  String toString() => 'RdcCursorEvent($cursor)';
}

/// One rendered desktop frame, copied out of the engine.
///
/// Raw pixels rather than an image type: this layer is also what the web build
/// compiles against, and `dart:ui` is not available there. Whoever paints it
/// knows what to do with RGBA.
class RdcFrame {
  const RdcFrame({
    required this.width,
    required this.height,
    required this.pixels,
  });

  final int width;
  final int height;

  /// RGBA, row by row from the top.
  final Uint8List pixels;

  @override
  String toString() => 'RdcFrame(${width}x$height, ${pixels.length} bytes)';
}

/// The engine hit a problem worth showing the user.
class RdcErrorEvent extends RdcEngineEvent {
  const RdcErrorEvent({required this.code, required this.message});

  final int code;
  final String message;

  @override
  String toString() => 'RdcErrorEvent($code, "$message")';
}

/// Why a session ended, as it crosses a route boundary.
///
/// A code and a kind, never a sentence: the layer that shows it chooses the
/// words, which is what keeps a failure from arriving as a `String` with no way
/// back to a translation. The shape is the one the session page already keeps
/// for its own failure, so it hands it over without converting.
typedef RdcSessionFailure = ({
  int code,
  String detail,
  RdcEngineError? engineError,
});

/// Window operations the session can ask for. Values match `RDC_WINDOW_*` in
/// `src/rdc_api.h`.
abstract final class RdcWindowCommand {
  static const int minimize = 1;
  static const int restore = 2;
  static const int toggleFullScreen = 3;
  static const int enterFullScreen = 4;
  static const int leaveFullScreen = 5;
}

/// Mouse actions the engine can be asked to send.
///
/// The values mirror `RDC_MOUSE_*` in `src/rdc_api.h` and are passed straight
/// through to the native queue, so the protocol flag bits stay on the native
/// side. `test/engine/rdc_engine_test.dart` pins them against the bridge
/// package's copy so the two cannot drift apart silently.
abstract final class RdcMouseAction {
  static const int move = 0;
  static const int leftDown = 1;
  static const int leftUp = 2;
  static const int rightDown = 3;
  static const int rightUp = 4;
  static const int middleDown = 5;
  static const int middleUp = 6;
  static const int wheel = 7;
}

/// Where remote audio is played. Values match `RDC_AUDIO_*` in `src/rdc_api.h`.
abstract final class RdcAudioPlayback {
  static const int onThisComputer = 0;
  static const int onRemote = 1;
  static const int never = 2;
}

/// A local folder exposed to the session as a network drive.
class RdcRedirectedFolder {
  const RdcRedirectedFolder({required this.path, this.name = ''});

  final String path;

  /// What the drive is called on the remote machine. Empty derives a name from
  /// the path.
  final String name;
}

/// RD Gateway settings for a connection.
class RdcGatewayRequest {
  const RdcGatewayRequest({
    required this.hostname,
    this.port = 443,
    this.username = '',
    this.password = '',
    this.domain = '',
    this.bypassForLocalAddresses = true,
  });

  final String hostname;
  final int port;
  final String username;
  final String password;
  final String domain;

  /// Skip the gateway for addresses on the local network.
  final bool bypassForLocalAddresses;
}

/// Everything needed to open a session.
///
/// Deliberately a plain value type owned by this layer rather than the bridge
/// package's equivalent: the interface has to stay implementable by the stub,
/// and the stub cannot import anything that pulls in `dart:ffi`.
class RdcConnectionRequest {
  const RdcConnectionRequest({
    required this.hostname,
    this.port = 3389,
    this.username = '',
    this.password = '',
    this.domain = '',
    this.desktopWidth = 1280,
    this.desktopHeight = 720,
    this.colorDepth = 32,
    this.adminSession = false,
    this.ignoreCertificate = false,
    this.reconnectIfDropped = true,
    this.audioPlayback = RdcAudioPlayback.onThisComputer,
    this.useMultiMonitor = false,
    this.gateway,
    this.folders = const [],
    this.redirectAllDrives = false,
  });

  final String hostname;
  final int port;
  final String username;
  final String password;
  final String domain;
  final int desktopWidth;
  final int desktopHeight;
  final int colorDepth;
  final bool adminSession;
  final bool ignoreCertificate;
  final bool reconnectIfDropped;

  /// Where remote audio is played. One of [RdcAudioPlayback].
  final int audioPlayback;

  /// Span the session across every local monitor.
  final bool useMultiMonitor;

  final RdcGatewayRequest? gateway;

  /// Local folders exposed to the session as network drives.
  final List<RdcRedirectedFolder> folders;

  /// Expose every drive instead of [folders].
  final bool redirectAllDrives;

  @override
  String toString() => 'RdcConnectionRequest($hostname:$port)';
}

/// The abstraction the UI is written against.
abstract class RdcEngine {
  /// Builds whichever implementation suits the current platform.
  static RdcEngine create() => createRdcEngine();

  /// False when no native implementation is available (web, or a platform the
  /// plugin was not built for). The UI uses this to explain itself instead of
  /// failing at the first session attempt.
  bool get isAvailable;

  /// Human-readable identification of the backend, shown in settings/about.
  String get backendName;

  /// Engine texture id to hand to a `Texture` widget, or -1 when the platform
  /// glue did not register one. Read once after startup.
  int get textureId;

  /// Events raised by the engine. Broadcast, so multiple listeners are fine.
  Stream<RdcEngineEvent> get events;

  /// Opens a session to a remote host. Returns immediately; the outcome
  /// arrives as events on [events].
  void connect(RdcConnectionRequest request);

  /// Starts the synthetic test-pattern session.
  ///
  /// This exists so the frame ring and the texture path can be exercised
  /// without a reachable RDP host. Mutually exclusive with [connect].
  int startTestPattern({required int width, required int height});

  /// Tears down whatever session is running.
  void stop();

  /// A copy of the most recently rendered desktop frame, or null when the
  /// session has not drawn anything yet.
  ///
  /// Used for the stored session preview the connection centre shows on a
  /// saved PC. A copy is taken rather than a view handed out, because the
  /// buffer belongs to the renderer.
  RdcFrame? captureFrame();

  /// Queues a mouse action at remote-desktop coordinates.
  void sendMouse(int action, int x, int y, {int wheelDelta = 0});

  /// Queues a key event. [scancode] is an 8-bit PS/2 set 1 code.
  void sendKey({
    required int scancode,
    required bool down,
    bool extended = false,
  });

  /// Types [text] into the session, bypassing keyboard layout.
  void sendText(String text);

  /// Sends the secure attention sequence.
  void sendCtrlAltDel();

  /// Whether the session takes over the keyboard.
  ///
  /// On: the keys Windows keeps for itself — the Windows key, Alt+Tab, Alt+Esc,
  /// Ctrl+Esc, Alt+F4, Ctrl+Space — go to the remote machine instead of this
  /// one, and the local input method is suspended for as long as it is on, so
  /// that typing reaches the host unmodified and the host's own input method
  /// composes. That is what makes a language whose input method lives on the
  /// host typable at all.
  ///
  /// Off: the keyboard is entirely the local machine's again. Turning it off
  /// restores the input method, so it has to happen when the session ends —
  /// otherwise the application's own fields cannot be typed into in Chinese.
  ///
  /// A no-op where the platform has no implementation.
  void setKeyboardCapture(bool enabled);

  /// Answers the certificate prompt raised by [RdcCertificateEvent], using one
  /// of the [RdcCertificateDecision] values.
  ///
  /// The session thread is blocked until this is called, and the connection is
  /// abandoned if no answer arrives within a minute, so a listener that never
  /// responds is not merely unhelpful — it fails the connection.
  void respondToCertificate(int decision);

  /// Tells the session that the local clipboard now holds [text], so the remote
  /// machine can be offered it on paste.
  ///
  /// Flutter has no clipboard-change notification, so the application polls and
  /// calls this when the value differs from the last one it announced.
  void setLocalClipboardText(String text);

  /// Drives the application window, for the session's full-screen and minimise
  /// controls. A no-op where the platform has no implementation.
  void runWindowCommand(int command);

  /// Whether the window is currently full screen.
  bool get isFullScreen;

  /// Asks the remote desktop to change resolution, for connections configured
  /// to follow the window size. A no-op where the host does not support it.
  void resizeDesktop(int width, int height);

  /// Whether saved passwords survive a restart on this platform.
  bool get isCredentialStorePersistent;

  /// Saves a password for [credentialId]. Returns true on success.
  Future<bool> storeCredential(String credentialId, String password);

  /// The saved password, or null when there is none.
  Future<String?> loadCredential(String credentialId);

  /// Removes a saved password.
  Future<void> deleteCredential(String credentialId);

  /// Releases native resources. The engine cannot be used afterwards.
  Future<void> dispose();
}
