/// Dart side of the OpenRDC native bridge.
///
/// The bindings here are written by hand rather than generated: the C ABI in
/// `src/rdc_api.h` is small and stable, and hand-writing keeps the package
/// buildable without LLVM/libclang installed. `ffigen.yaml` is kept in sync so
/// `dart run ffigen --config ffigen.yaml` remains an option once libclang is
/// available.
///
/// Everything below is a plain synchronous FFI call. They are all either
/// constant-time accessors or queue-style operations that return immediately,
/// so none of them may ever be called in a way that blocks the UI isolate for a
/// meaningful amount of time. Session work happens on native threads.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ---------------------------------------------------------------------------
// Constants mirrored from src/rdc_api.h
// ---------------------------------------------------------------------------

/// Session states reported through [RdcEvent.state].
abstract final class RdcState {
  static const int idle = 0;
  static const int connecting = 1;
  static const int authenticating = 2;
  static const int connected = 3;
  static const int disconnecting = 4;
  static const int disconnected = 5;
  static const int failed = 6;

  static String describe(int state) => switch (state) {
    idle => '空闲',
    connecting => '正在连接',
    authenticating => '正在验证',
    connected => '已连接',
    disconnecting => '正在断开',
    disconnected => '已断开',
    failed => '连接失败',
    _ => '未知状态($state)',
  };
}

/// Event kinds pushed from native to Dart.
abstract final class RdcEventKind {
  static const int state = 1;
  static const int desktopSize = 2;
  static const int error = 3;

  /// A certificate needs approval before the connection can continue. The
  /// session thread is blocked until [RdcBridge.respondToCertificate] is
  /// called, so this must be acted on promptly.
  static const int certificate = 4;

  /// Text has arrived from the remote machine's clipboard. Read it with
  /// [RdcBridge.takeRemoteClipboardText].
  static const int clipboard = 5;

  /// The remote machine's pointer changed shape. Read it with
  /// [RdcBridge.currentCursor].
  static const int cursor = 6;
}

/// What the remote machine's pointer is. Values match `RDC_CURSOR_*` in
/// src/rdc_api.h.
abstract final class RdcCursorKind {
  /// The remote machine is asking for the ordinary arrow.
  static const int defaultArrow = 0;

  /// The remote machine has hidden the pointer, e.g. while playing a video.
  static const int hidden = 1;

  /// A picture, in [RdcCursorShape.pixels].
  static const int image = 2;
}

/// Result codes returned by the native entry points.
abstract final class RdcResult {
  static const int ok = 0;
  static const int errNoTextureRegistrar = -1;
  static const int errAlreadyRunning = -2;
  static const int errBadArgument = -3;
  static const int errNotImplemented = -4;
  static const int errNoCredentials = -5;
  static const int errAuthFailed = -6;
  static const int errNotFound = -7;
  static const int errPlatform = -8;

  // Failures below are about the session or the engine rather than the
  // connection. They are separate codes so the application can tell "could not
  // reach it" from "the engine could not start", which are different things to
  // say to a user.
  static const int errSessionContext = -9;
  static const int errSessionStart = -10;
  static const int errEventHandles = -11;
  static const int errEventWait = -12;
  static const int errGdiInit = -13;
  static const int errConnectFailed = -14;
  static const int errTlsFailed = -15;
  static const int errPasswordExpired = -16;

  static String describe(int code) => switch (code) {
    ok => '成功',
    errNoTextureRegistrar => '未取得纹理注册器',
    errAlreadyRunning => '会话已在运行',
    errBadArgument => '参数无效',
    errNotImplemented => '尚未实现',
    errNoCredentials => '缺少凭据',
    errAuthFailed => '身份验证失败',
    errNotFound => '未找到',
    errSessionContext => '无法创建会话上下文',
    errSessionStart => '会话无法启动',
    errEventHandles => '无法获取会话事件句柄',
    errEventWait => '等待会话事件失败',
    errGdiInit => '无法初始化渲染',
    errConnectFailed => '无法连接到远程电脑',
    errTlsFailed => '安全连接失败',
    errPasswordExpired => '密码已过期',
    errPlatform => '系统调用失败',
    _ => '未知错误($code)',
  };
}

// ---------------------------------------------------------------------------
// Native signatures
// ---------------------------------------------------------------------------

typedef _VersionNative = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

typedef _SetEventSinkNative =
    Void Function(
      Pointer<NativeFunction<Void Function(Int32, Int32, Pointer<Utf8>)>>,
    );
typedef _SetEventSinkDart =
    void Function(
      Pointer<NativeFunction<Void Function(Int32, Int32, Pointer<Utf8>)>>,
    );

typedef _SetTextureIdNative = Void Function(Int64);
typedef _SetTextureIdDart = void Function(int);

typedef _TextureIdNative = Int64 Function();
typedef _TextureIdDart = int Function();

typedef _BytesPerPixelNative = Int32 Function();
typedef _BytesPerPixelDart = int Function();

typedef _FrameAcquireNative =
    Pointer<Uint8> Function(
      Pointer<Int32>,
      Pointer<Int32>,
      Pointer<Int32>,
      Pointer<Int32>,
    );
typedef _FrameAcquireDart =
    Pointer<Uint8> Function(
      Pointer<Int32>,
      Pointer<Int32>,
      Pointer<Int32>,
      Pointer<Int32>,
    );

typedef _FrameReleaseNative = Void Function(Int32);
typedef _FrameReleaseDart = void Function(int);

typedef _StartNative = Int32 Function(Int32, Int32);
typedef _StartDart = int Function(int, int);

typedef _StopNative = Void Function();
typedef _StopDart = void Function();

typedef _ConnectNative = Int32 Function(Pointer<_RdcConnectParamsNative>);
typedef _ConnectDart = int Function(Pointer<_RdcConnectParamsNative>);

typedef _DisconnectNative = Void Function();
typedef _DisconnectDart = void Function();

typedef _IsConnectedNative = Int32 Function();
typedef _IsConnectedDart = int Function();

typedef _MouseNative = Void Function(Int32, Int32, Int32, Int32);
typedef _MouseDart = void Function(int, int, int, int);

typedef _KeyNative = Void Function(Int32, Int32, Int32);
typedef _KeyDart = void Function(int, int, int);

typedef _KeyboardCaptureNative = Void Function(Int32);
typedef _KeyboardCaptureDart = void Function(int);

typedef _CursorInfoNative = Int32 Function(Pointer<_RdcCursorInfoNative>);
typedef _CursorInfoDart = int Function(Pointer<_RdcCursorInfoNative>);

typedef _CursorCopyNative = Int32 Function(Pointer<Uint8>, Int32);
typedef _CursorCopyDart = int Function(Pointer<Uint8>, int);

/// Mirrors `rdc_cursor_info` in src/rdc_api.h.
final class _RdcCursorInfoNative extends Struct {
  @Int32()
  external int kind;
  @Int32()
  external int width;
  @Int32()
  external int height;
  @Int32()
  external int hotspotX;
  @Int32()
  external int hotspotY;
  @Int32()
  external int byteLength;
}

/// Mirrors `rdc_cursor_info` in src/rdc_api.h: the remote machine's pointer.
///
/// RDP sends cursors as pictures rather than as named shapes, so anything other
/// than the ordinary arrow arrives as pixels to draw — Flutter has no API for a
/// bitmap cursor, which is why this is a picture and not a [MouseCursor].
class RdcCursorInfo {
  const RdcCursorInfo({
    required this.kind,
    this.width = 0,
    this.height = 0,
    this.hotspotX = 0,
    this.hotspotY = 0,
    this.pixels,
  });

  /// One of [RdcCursorKind].
  final int kind;

  final int width;
  final int height;

  /// The point in the picture that sits under the pointer.
  final int hotspotX;
  final int hotspotY;

  /// RGBA, row by row from the top, or null when [kind] is not
  /// [RdcCursorKind.image].
  final Uint8List? pixels;

  @override
  String toString() =>
      'RdcCursorInfo(kind: $kind, ${width}x$height, hotspot: $hotspotX,$hotspotY)';
}

typedef _TextNative = Void Function(Pointer<Uint16>, Int32);
typedef _TextDart = void Function(Pointer<Uint16>, int);

/// Mirrors `rdc_connect_params` in src/rdc_api.h.
///
/// Field order and types must match exactly. Booleans are int32 there rather
/// than C `bool` so the layout does not depend on the compiler, which is why
/// they are [Int32] here too.
final class _RdcConnectParamsNative extends Struct {
  external Pointer<Utf8> hostname;
  @Int32()
  external int port;
  external Pointer<Utf8> username;
  external Pointer<Utf8> password;
  external Pointer<Utf8> domain;
  @Int32()
  external int desktopWidth;
  @Int32()
  external int desktopHeight;
  @Int32()
  external int colorDepth;
  @Int32()
  external int adminSession;
  @Int32()
  external int ignoreCertificate;
  @Int32()
  external int reconnectIfDropped;
  @Int32()
  external int audioPlayback;
  @Int32()
  external int useMultimon;
  @Int32()
  external int useGateway;
  external Pointer<Utf8> gatewayHostname;
  @Int32()
  external int gatewayBypassLocal;
  @Int32()
  external int gatewayPort;
  external Pointer<Utf8> gatewayUsername;
  external Pointer<Utf8> gatewayPassword;
  external Pointer<Utf8> gatewayDomain;
}

/// What to connect to. Mirrors the connection settings the UI collects.
class RdcConnectParams {
  const RdcConnectParams({
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

  final RdcGatewayParams? gateway;

  /// Local folders to expose to the session as network drives.
  final List<RdcRedirectedFolderParams> folders;

  /// Expose every drive on this machine instead of [folders].
  final bool redirectAllDrives;

  @override
  String toString() => 'RdcConnectParams($hostname:$port as "$username")';
}

/// Where remote audio is played. Values match `RDC_AUDIO_*` in src/rdc_api.h.
abstract final class RdcAudioPlayback {
  static const int onThisComputer = 0;
  static const int onRemote = 1;
  static const int never = 2;
}

/// A local folder exposed to the session as a network drive.
class RdcRedirectedFolderParams {
  const RdcRedirectedFolderParams({required this.path, this.name = ''});

  final String path;

  /// What the drive is called on the remote machine. Empty derives a name from
  /// the path.
  final String name;
}

/// Remote Desktop Gateway settings for a connection.
class RdcGatewayParams {
  const RdcGatewayParams({
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

typedef _PendingCertificateNative =
    Int32 Function(Pointer<_RdcCertificateInfoNative>);
typedef _PendingCertificateDart =
    int Function(Pointer<_RdcCertificateInfoNative>);

typedef _RespondCertificateNative = Void Function(Int32);
typedef _RespondCertificateDart = void Function(int);

typedef _SetLocalClipboardNative = Void Function(Pointer<Uint16>, Int32);
typedef _SetLocalClipboardDart = void Function(Pointer<Uint16>, int);

typedef _ClipboardPendingLengthNative = Int32 Function();
typedef _ClipboardPendingLengthDart = int Function();

typedef _ClipboardTakeNative = Int32 Function(Pointer<Uint16>, Int32);
typedef _ClipboardTakeDart = int Function(Pointer<Uint16>, int);

typedef _WindowCommandNative = Void Function(Int32);
typedef _WindowCommandDart = void Function(int);

typedef _IsFullScreenNative = Int32 Function();
typedef _IsFullScreenDart = int Function();

typedef _AddRedirectedFolderNative =
    Void Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _AddRedirectedFolderDart = void Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _SetRedirectAllDrivesNative = Void Function(Int32);
typedef _SetRedirectAllDrivesDart = void Function(int);

typedef _ResizeDesktopNative = Void Function(Int32, Int32);
typedef _ResizeDesktopDart = void Function(int, int);

typedef _CredentialStoreNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _CredentialStoreDart = int Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _CredentialLoadNative =
    Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _CredentialLoadDart = int Function(Pointer<Utf8>, Pointer<Utf8>, int);

typedef _CredentialSizeNative = Int32 Function(Pointer<Utf8>);
typedef _CredentialSizeDart = int Function(Pointer<Utf8>);

typedef _CredentialDeleteNative = Int32 Function(Pointer<Utf8>);
typedef _CredentialDeleteDart = int Function(Pointer<Utf8>);

/// Window operations the session can ask for. Values match `RDC_WINDOW_*`.
abstract final class RdcWindowCommand {
  static const int minimize = 1;
  static const int restore = 2;
  static const int toggleFullScreen = 3;
  static const int enterFullScreen = 4;
  static const int leaveFullScreen = 5;
}

/// Mirrors `rdc_certificate_info` in src/rdc_api.h.
final class _RdcCertificateInfoNative extends Struct {
  external Pointer<Utf8> host;
  @Int32()
  external int port;
  external Pointer<Utf8> commonName;
  external Pointer<Utf8> subject;
  external Pointer<Utf8> issuer;
  external Pointer<Utf8> fingerprint;
  @Int32()
  external int changed;
  @Int32()
  external int nameMismatch;
  external Pointer<Utf8> oldFingerprint;
}

/// Details of a certificate the session is waiting on approval for.
class RdcCertificateInfo {
  const RdcCertificateInfo({
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
  final String commonName;
  final String subject;
  final String issuer;
  final String fingerprint;

  /// True when this differs from the certificate previously accepted for the
  /// host, which is the case that deserves real scrutiny.
  final bool changed;

  /// True when the name in the certificate is not the host being connected to.
  final bool nameMismatch;

  final String oldFingerprint;

  @override
  String toString() => 'RdcCertificateInfo($host:$port, changed: $changed)';
}

/// How to answer a certificate prompt. Values match `RDC_CERT_*`.
abstract final class RdcCertificateDecision {
  static const int reject = 0;
  static const int acceptAndStore = 1;
  static const int acceptOnce = 2;
}

/// Which mouse action an [RdcBridge.sendMouse] call represents.
///
/// The values match the `RDC_MOUSE_*` constants in src/rdc_api.h. Keeping the
/// protocol flag bits on the native side means the Dart layer never has to know
/// them.
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

/// A notification raised from a native thread.
class RdcEvent {
  const RdcEvent({
    required this.kind,
    required this.code,
    required this.message,
  });

  final int kind;
  final int code;
  final String message;

  /// Non-null for events delivered as [RdcEventKind.state].
  int? get state => kind == RdcEventKind.state ? code : null;

  /// Non-null for events delivered as [RdcEventKind.desktopSize].
  (int width, int height)? get desktopSize {
    if (kind != RdcEventKind.desktopSize) {
      return null;
    }
    final parts = message.split('x');
    if (parts.length != 2) {
      return null;
    }
    final width = int.tryParse(parts[0]);
    final height = int.tryParse(parts[1]);
    if (width == null || height == null) {
      return null;
    }
    return (width, height);
  }

  @override
  String toString() =>
      'RdcEvent(kind: $kind, code: $code, message: "$message")';
}

/// Thrown when the native library cannot be loaded at all.
class RdcUnavailableException implements Exception {
  RdcUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'RdcUnavailableException: $message';
}

// ---------------------------------------------------------------------------
// Bridge
// ---------------------------------------------------------------------------

/// Direct, thin access to the native core. Most callers should use the engine
/// abstraction in the application instead of talking to this class.
class RdcBridge {
  RdcBridge._(DynamicLibrary library)
    : _version = library.lookupFunction<_VersionNative, _VersionDart>(
        'rdc_version',
      ),
      _setEventSink = library
          .lookupFunction<_SetEventSinkNative, _SetEventSinkDart>(
            'rdc_set_event_sink',
          ),
      _setTextureId = library
          .lookupFunction<_SetTextureIdNative, _SetTextureIdDart>(
            'rdc_set_texture_id',
          ),
      _textureId = library.lookupFunction<_TextureIdNative, _TextureIdDart>(
        'rdc_texture_id',
      ),
      _bytesPerPixel = library
          .lookupFunction<_BytesPerPixelNative, _BytesPerPixelDart>(
            'rdc_bytes_per_pixel',
          ),
      _startTestPattern = library.lookupFunction<_StartNative, _StartDart>(
        'rdc_testpattern_start',
      ),
      _stopTestPattern = library.lookupFunction<_StopNative, _StopDart>(
        'rdc_testpattern_stop',
      ),
      _connect = library.lookupFunction<_ConnectNative, _ConnectDart>(
        'rdc_connect',
      ),
      _disconnect = library.lookupFunction<_DisconnectNative, _DisconnectDart>(
        'rdc_disconnect',
      ),
      _isConnected = library
          .lookupFunction<_IsConnectedNative, _IsConnectedDart>(
            'rdc_is_connected',
          ),
      _mouse = library.lookupFunction<_MouseNative, _MouseDart>('rdc_mouse'),
      _key = library.lookupFunction<_KeyNative, _KeyDart>('rdc_key'),
      _text = library.lookupFunction<_TextNative, _TextDart>('rdc_text'),
      _ctrlAltDel = library.lookupFunction<_StopNative, _StopDart>(
        'rdc_ctrl_alt_del',
      ),
      _keyboardCapture = library
          .lookupFunction<_KeyboardCaptureNative, _KeyboardCaptureDart>(
            'rdc_keyboard_capture',
          ),
      _cursorInfo = library.lookupFunction<_CursorInfoNative, _CursorInfoDart>(
        'rdc_current_cursor',
      ),
      _cursorCopy = library.lookupFunction<_CursorCopyNative, _CursorCopyDart>(
        'rdc_cursor_copy',
      ),
      _frameAcquire = library
          .lookupFunction<_FrameAcquireNative, _FrameAcquireDart>(
            'rdc_frame_acquire',
          ),
      _frameRelease = library
          .lookupFunction<_FrameReleaseNative, _FrameReleaseDart>(
            'rdc_frame_release',
          ),
      _pendingCertificate = library
          .lookupFunction<_PendingCertificateNative, _PendingCertificateDart>(
            'rdc_pending_certificate',
          ),
      _respondCertificate = library
          .lookupFunction<_RespondCertificateNative, _RespondCertificateDart>(
            'rdc_respond_certificate',
          ),
      _setLocalClipboard = library
          .lookupFunction<_SetLocalClipboardNative, _SetLocalClipboardDart>(
            'rdc_clipboard_set_local',
          ),
      _clipboardPendingLength = library
          .lookupFunction<
            _ClipboardPendingLengthNative,
            _ClipboardPendingLengthDart
          >('rdc_clipboard_pending_length'),
      _clipboardTake = library
          .lookupFunction<_ClipboardTakeNative, _ClipboardTakeDart>(
            'rdc_clipboard_take',
          ),
      _windowCommand = library
          .lookupFunction<_WindowCommandNative, _WindowCommandDart>(
            'rdc_window_command',
          ),
      _isFullScreen = library
          .lookupFunction<_IsFullScreenNative, _IsFullScreenDart>(
            'rdc_window_is_fullscreen',
          ),
      _addRedirectedFolder = library
          .lookupFunction<_AddRedirectedFolderNative, _AddRedirectedFolderDart>(
            'rdc_add_redirected_folder',
          ),
      _setRedirectAllDrives = library
          .lookupFunction<
            _SetRedirectAllDrivesNative,
            _SetRedirectAllDrivesDart
          >('rdc_set_redirect_all_drives'),
      _resizeDesktop = library
          .lookupFunction<_ResizeDesktopNative, _ResizeDesktopDart>(
            'rdc_resize_desktop',
          ),
      _credentialStore = library
          .lookupFunction<_CredentialStoreNative, _CredentialStoreDart>(
            'rdc_credential_store',
          ),
      _credentialLoad = library
          .lookupFunction<_CredentialLoadNative, _CredentialLoadDart>(
            'rdc_credential_load',
          ),
      _credentialSize = library
          .lookupFunction<_CredentialSizeNative, _CredentialSizeDart>(
            'rdc_credential_size',
          ),
      _credentialDelete = library
          .lookupFunction<_CredentialDeleteNative, _CredentialDeleteDart>(
            'rdc_credential_delete',
          );

  static RdcBridge? _instance;

  /// Whether the native library is loadable on this platform. False on web and
  /// anywhere the plugin is not built.
  static bool get isSupported => Platform.isWindows;

  /// Loads the native library once. Throws [RdcUnavailableException] when it is
  /// missing, which in practice means the app was built without the plugin.
  static RdcBridge get instance {
    final existing = _instance;
    if (existing != null) {
      return existing;
    }
    if (!isSupported) {
      throw RdcUnavailableException(
        '远程桌面引擎不支持当前平台 (${Platform.operatingSystem})',
      );
    }
    try {
      final library = DynamicLibrary.open('rdc_bridge.dll');
      return _instance = RdcBridge._(library);
    } on Object catch (error) {
      throw RdcUnavailableException('无法加载 rdc_bridge.dll: $error');
    }
  }

  final _VersionDart _version;
  final _SetEventSinkDart _setEventSink;
  final _SetTextureIdDart _setTextureId;
  final _TextureIdDart _textureId;
  final _BytesPerPixelDart _bytesPerPixel;
  final _StartDart _startTestPattern;
  final _StopDart _stopTestPattern;
  final _ConnectDart _connect;
  final _DisconnectDart _disconnect;
  final _IsConnectedDart _isConnected;
  final _MouseDart _mouse;
  final _KeyDart _key;
  final _TextDart _text;
  final _StopDart _ctrlAltDel;
  final _KeyboardCaptureDart _keyboardCapture;
  final _CursorInfoDart _cursorInfo;
  final _CursorCopyDart _cursorCopy;
  final _FrameAcquireDart _frameAcquire;
  final _FrameReleaseDart _frameRelease;
  final _PendingCertificateDart _pendingCertificate;
  final _RespondCertificateDart _respondCertificate;
  final _SetLocalClipboardDart _setLocalClipboard;
  final _ClipboardPendingLengthDart _clipboardPendingLength;
  final _ClipboardTakeDart _clipboardTake;
  final _WindowCommandDart _windowCommand;
  final _IsFullScreenDart _isFullScreen;
  final _AddRedirectedFolderDart _addRedirectedFolder;
  final _SetRedirectAllDrivesDart _setRedirectAllDrives;
  final _ResizeDesktopDart _resizeDesktop;
  final _CredentialStoreDart _credentialStore;
  final _CredentialLoadDart _credentialLoad;
  final _CredentialSizeDart _credentialSize;
  final _CredentialDeleteDart _credentialDelete;

  NativeCallable<Void Function(Int32, Int32, Pointer<Utf8>)>? _eventCallable;

  /// The version string of the native bridge, including the FreeRDP version
  /// once it is linked in.
  String get version => _version().toDartString();

  /// The engine texture id frames are published to, or -1 when the platform
  /// glue did not manage to register one.
  int get textureId => _textureId();

  /// Bytes per pixel of every frame the native side produces. Always 4.
  int get bytesPerPixel => _bytesPerPixel();

  /// Registers [onEvent] to receive native notifications. Passing null
  /// unregisters.
  ///
  /// The callback runs on the isolate that created the callable, so calling
  /// this from the main isolate delivers events straight to the UI isolate's
  /// event loop even though the native side raises them on its own threads.
  void setEventSink(void Function(RdcEvent event)? onEvent) {
    _eventCallable?.close();
    _eventCallable = null;

    if (onEvent == null) {
      _setEventSink(nullptr);
      return;
    }

    final callable =
        NativeCallable<Void Function(Int32, Int32, Pointer<Utf8>)>.listener((
          int kind,
          int code,
          Pointer<Utf8> message,
        ) {
          onEvent(
            RdcEvent(kind: kind, code: code, message: message.toDartString()),
          );
        });
    _eventCallable = callable;
    _setEventSink(callable.nativeFunction);
  }

  /// Overrides the engine texture id. The platform glue normally sets this; it
  /// exists so tests can drive the bridge without a real engine.
  void setTextureId(int id) => _setTextureId(id);

  /// Opens a session. Returns immediately; progress arrives through the event
  /// sink installed with [setEventSink].
  int connect(RdcConnectParams request) {
    final params = calloc<_RdcConnectParamsNative>();
    // Every native string is copied by rdc_connect before it returns, so these
    // only have to outlive the call.
    final strings = <Pointer<Utf8>>[];

    Pointer<Utf8> own(String value) {
      final pointer = value.toNativeUtf8();
      strings.add(pointer);
      return pointer;
    }

    try {
      final gateway = request.gateway;
      params.ref
        ..hostname = own(request.hostname)
        ..port = request.port
        ..username = own(request.username)
        ..password = own(request.password)
        ..domain = own(request.domain)
        ..desktopWidth = request.desktopWidth
        ..desktopHeight = request.desktopHeight
        ..colorDepth = request.colorDepth
        ..adminSession = request.adminSession ? 1 : 0
        ..ignoreCertificate = request.ignoreCertificate ? 1 : 0
        ..reconnectIfDropped = request.reconnectIfDropped ? 1 : 0
        ..audioPlayback = request.audioPlayback
        ..useMultimon = request.useMultiMonitor ? 1 : 0
        ..useGateway = gateway == null ? 0 : 1
        ..gatewayHostname = own(gateway?.hostname ?? '')
        ..gatewayBypassLocal = (gateway?.bypassForLocalAddresses ?? true)
            ? 1
            : 0
        ..gatewayPort = gateway?.port ?? 0
        ..gatewayUsername = own(gateway?.username ?? '')
        ..gatewayPassword = own(gateway?.password ?? '')
        ..gatewayDomain = own(gateway?.domain ?? '');

      // Staged redirection has to be queued before connecting: the native side
      // consumes it when it builds the session's settings, and clears it
      // afterwards so a retry does not accumulate duplicates.
      for (final folder in request.folders) {
        _addRedirectedFolder(own(folder.name), own(folder.path));
      }
      if (request.redirectAllDrives) {
        _setRedirectAllDrives(1);
      }

      return _connect(params);
    } finally {
      for (final pointer in strings) {
        calloc.free(pointer);
      }
      calloc.free(params);
    }
  }

  /// Asks the running session to stop. Returns immediately.
  void disconnect() => _disconnect();

  bool get isConnected => _isConnected() != 0;

  /// Queues a mouse action. [wheelDelta] is in notches and only used by
  /// [RdcMouseAction.wheel].
  void sendMouse(int action, int x, int y, {int wheelDelta = 0}) =>
      _mouse(action, x, y, wheelDelta);

  /// Queues a key event. [scancode] is an 8-bit PS/2 set 1 code; [extended]
  /// marks the grey navigation and keypad keys.
  void sendKey({
    required int scancode,
    required bool down,
    bool extended = false,
  }) => _key(scancode, down ? 1 : 0, extended ? 1 : 0);

  /// Types [text] as UTF-16 code units, bypassing keyboard layout entirely.
  void sendText(String text) {
    if (text.isEmpty) {
      return;
    }
    final units = text.codeUnits;
    final buffer = calloc<Uint16>(units.length);
    try {
      for (var i = 0; i < units.length; i++) {
        buffer[i] = units[i];
      }
      _text(buffer, units.length);
    } finally {
      calloc.free(buffer);
    }
  }

  void sendCtrlAltDel() => _ctrlAltDel();

  /// Hands the session the keys Windows keeps for itself, and detaches the local
  /// input method for as long as it is on.
  ///
  /// Must be called from the UI isolate, and only while a session is running:
  /// the native side installs a low-level keyboard hook, which is delivered to
  /// the thread that installed it, and that thread has to be the one pumping the
  /// window's messages. See `rdc_keyboard_capture` in src/rdc_api.h.
  void setKeyboardCapture(bool enabled) => _keyboardCapture(enabled ? 1 : 0);

  /// Details of the certificate the session is waiting on approval for.
  ///
  /// Called in response to an [RdcEventKind.certificate] event. Returns null
  /// when nothing is pending, which happens if the prompt timed out before the
  /// UI got to it.
  ///
  /// The native side owns every string here; they are copied out immediately so
  /// nothing outlives the buffer.
  RdcCertificateInfo? pendingCertificate() {
    final buffer = calloc<_RdcCertificateInfoNative>();
    try {
      if (_pendingCertificate(buffer) != 0) {
        return null;
      }
      final info = buffer.ref;
      return RdcCertificateInfo(
        host: info.host.toDartString(),
        port: info.port,
        commonName: info.commonName.toDartString(),
        subject: info.subject.toDartString(),
        issuer: info.issuer.toDartString(),
        fingerprint: info.fingerprint.toDartString(),
        changed: info.changed != 0,
        nameMismatch: info.nameMismatch != 0,
        oldFingerprint: info.oldFingerprint.toDartString(),
      );
    } finally {
      calloc.free(buffer);
    }
  }

  /// Answers a pending certificate prompt, unblocking the session thread.
  /// A no-op when nothing is pending.
  void respondToCertificate(int decision) => _respondCertificate(decision);

  /// Announces local clipboard text to the remote machine.
  ///
  /// The text is copied, so the caller may free or reuse anything it passed in.
  /// A no-op when no session is running.
  void setLocalClipboardText(String text) {
    final units = text.codeUnits;
    if (units.isEmpty) {
      return;
    }
    final buffer = calloc<Uint16>(units.length);
    try {
      for (var i = 0; i < units.length; i++) {
        buffer[i] = units[i];
      }
      _setLocalClipboard(buffer, units.length);
    } finally {
      calloc.free(buffer);
    }
  }

  /// Performs a window command, e.g. [RdcWindowCommand.toggleFullScreen].
  /// A no-op on platforms with no window implementation.
  void windowCommand(int command) => _windowCommand(command);

  /// Whether the window is currently in the borderless full-screen state.
  bool get isFullScreen => _isFullScreen() != 0;

  /// Asks the remote machine to change its desktop resolution.
  ///
  /// Queued and sent from the session thread. Only hosts supporting display
  /// control (Windows 8 / Server 2012 onwards) act on it; the resulting size,
  /// which the host may clamp, arrives as a desktop-size event.
  void resizeDesktop(int width, int height) => _resizeDesktop(width, height);

  /// Saves a password to the platform's secret store. Returns [RdcResult.ok] or
  /// a negative code.
  int storeCredential(String credentialId, String password) {
    final id = credentialId.toNativeUtf8();
    final secret = password.toNativeUtf8();
    try {
      return _credentialStore(id, secret);
    } finally {
      calloc.free(id);
      calloc.free(secret);
    }
  }

  /// Reads a saved password, or null when nothing is stored under [credentialId]
  /// or the platform has no secret store.
  String? loadCredential(String credentialId) {
    final id = credentialId.toNativeUtf8();
    try {
      // Two calls: the size first, so the buffer is exactly the right length
      // rather than a guess that could truncate a long password.
      final size = _credentialSize(id);
      if (size <= 0) {
        return null;
      }

      final buffer = calloc<Uint8>(size);
      try {
        if (_credentialLoad(id, buffer.cast<Utf8>(), size) != RdcResult.ok) {
          return null;
        }
        return buffer.cast<Utf8>().toDartString();
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc.free(id);
    }
  }

  /// Removes a saved password. Returns [RdcResult.ok] even when none was stored.
  int deleteCredential(String credentialId) {
    final id = credentialId.toNativeUtf8();
    try {
      return _credentialDelete(id);
    } finally {
      calloc.free(id);
    }
  }

  /// Text received from the remote machine's clipboard, or null when there is
  /// none waiting.
  String? takeRemoteClipboardText() {
    final length = _clipboardPendingLength();
    if (length <= 0) {
      return null;
    }

    final buffer = calloc<Uint16>(length);
    try {
      final copied = _clipboardTake(buffer, length);
      if (copied <= 0) {
        return null;
      }
      return String.fromCharCodes(buffer.asTypedList(copied));
    } finally {
      calloc.free(buffer);
    }
  }

  /// A copy of the most recently rendered desktop frame as (width, height, RGBA
  /// pixels), or null when nothing has been rendered yet.
  ///
  /// The frame ring belongs to the renderer and is read on its own thread, so
  /// this takes a copy rather than handing out the buffer: the presenter may
  /// re-upload while the caller is still looking at it. The copy is short-lived
  /// either way, because the ring will not reuse a pinned slot.
  (int width, int height, Uint8List pixels)? captureFrame() {
    final width = calloc<Int32>();
    final height = calloc<Int32>();
    final stride = calloc<Int32>();
    final token = calloc<Int32>();
    try {
      final pixels = _frameAcquire(width, height, stride, token);
      if (pixels == nullptr) {
        return null;
      }
      try {
        final w = width.value;
        final h = height.value;
        final s = stride.value;
        if (w <= 0 || h <= 0 || s < w * 4) {
          return null;
        }
        // Copied row by row, because the stride is the ring's business and is
        // not promised to be exactly four bytes per pixel.
        final source = pixels.asTypedList(s * h);
        final out = Uint8List(w * h * 4);
        for (var y = 0; y < h; y++) {
          out.setRange(y * w * 4, (y + 1) * w * 4, source, y * s);
        }
        return (w, h, out);
      } finally {
        _frameRelease(token.value);
      }
    } finally {
      calloc.free(width);
      calloc.free(height);
      calloc.free(stride);
      calloc.free(token);
    }
  }

  /// The remote machine's pointer as it stands, or null when this is not
  /// possible (no session, or a platform without one).
  ///
  /// Called in response to an [RdcEventKind.cursor] event. The remote machine
  /// sends the pointer as a picture, so anything but the ordinary arrow arrives
  /// here as pixels, which the caller draws itself.
  RdcCursorInfo? currentCursor() {
    final buffer = calloc<_RdcCursorInfoNative>();
    try {
      if (_cursorInfo(buffer) != RdcResult.ok) {
        return null;
      }
      final info = buffer.ref;
      if (info.kind != RdcCursorKind.image || info.byteLength <= 0) {
        return RdcCursorInfo(kind: info.kind);
      }

      final pixels = calloc<Uint8>(info.byteLength);
      try {
        final copied = _cursorCopy(pixels, info.byteLength);
        if (copied <= 0) {
          return RdcCursorInfo(kind: info.kind);
        }
        return RdcCursorInfo(
          kind: info.kind,
          width: info.width,
          height: info.height,
          hotspotX: info.hotspotX,
          hotspotY: info.hotspotY,
          pixels: Uint8List.fromList(pixels.asTypedList(copied)),
        );
      } finally {
        calloc.free(pixels);
      }
    } finally {
      calloc.free(buffer);
    }
  }

  /// Starts the synthetic session used to validate the pipeline. See
  /// `src/rdc_testpattern.h` for what it draws and why.
  int startTestPattern({required int width, required int height}) =>
      _startTestPattern(width, height);

  void stopTestPattern() => _stopTestPattern();
}
