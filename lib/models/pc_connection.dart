/// A saved remote PC: everything needed to open a session, and nothing secret.
///
/// The field set mirrors the Windows App's add/edit PC form, which is split
/// across four tabs. The nested [PcDisplaySettings] and [PcRedirectionSettings]
/// exist so the form, the store and the session starter can each speak about
/// one concern at a time instead of a thirty-argument constructor.
library;

import 'package:flutter/foundation.dart';

import 'credential.dart';
import 'json_utils.dart';

/// A remote desktop resolution. Kept as a value object so the picker can offer
/// a fixed list and custom sizes behave the same way.
@immutable
class Resolution {
  const Resolution(this.width, this.height);

  final int width;
  final int height;

  static const Resolution hd = Resolution(1280, 720);
  static const Resolution fullHd = Resolution(1920, 1080);
  static const Resolution qhd = Resolution(2560, 1440);

  /// The sizes the picker offers, matching the app's own list closely enough.
  static const List<Resolution> presets = [
    Resolution(1024, 768),
    Resolution(1280, 720),
    Resolution(1280, 1024),
    Resolution(1366, 768),
    Resolution(1600, 900),
    Resolution(1920, 1080),
    Resolution(1920, 1200),
    Resolution(2560, 1440),
    Resolution(3840, 2160),
  ];

  double get aspectRatio => height == 0 ? 1 : width / height;

  String get label => '$width × $height';

  @override
  bool operator ==(Object other) =>
      other is Resolution && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => label;
}

/// How the session should map onto the local displays.
enum DisplayMode {
  allDisplays,
  singleDisplay,
  selectDisplays;

  static DisplayMode fromName(String? name) => DisplayMode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => DisplayMode.allDisplays,
  );
}

/// Which way clipboard text may travel.
enum ClipboardMode {
  bidirectional,
  localToRemote,
  remoteToLocal,
  disabled;

  bool get allowsLocalToRemote =>
      this == bidirectional || this == localToRemote;
  bool get allowsRemoteToLocal =>
      this == bidirectional || this == remoteToLocal;

  static ClipboardMode fromName(String? name) =>
      ClipboardMode.values.firstWhere(
        (mode) => mode.name == name,
        orElse: () => ClipboardMode.bidirectional,
      );
}

/// Where remote audio should be played.
enum AudioPlaybackMode {
  onThisComputer,
  onRemotePc,
  never;

  static AudioPlaybackMode fromName(String? name) =>
      AudioPlaybackMode.values.firstWhere(
        (mode) => mode.name == name,
        orElse: () => AudioPlaybackMode.onThisComputer,
      );
}

/// One local folder shared into the session.
@immutable
class RedirectedFolder {
  const RedirectedFolder({required this.path, this.readOnly = false});

  final String path;
  final bool readOnly;

  /// The name Windows would show for this share, i.e. the last path segment.
  String get shareName {
    final normalised = path.replaceAll('\\', '/');
    final segments = normalised.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? path : segments.last;
  }

  RedirectedFolder copyWith({String? path, bool? readOnly}) => RedirectedFolder(
    path: path ?? this.path,
    readOnly: readOnly ?? this.readOnly,
  );

  Map<String, Object?> toJson() => {'path': path, 'readOnly': readOnly};

  factory RedirectedFolder.fromJson(Map<String, Object?> json) =>
      RedirectedFolder(
        path: asString(json['path']),
        readOnly: asBool(json['readOnly'], false),
      );

  @override
  bool operator ==(Object other) =>
      other is RedirectedFolder &&
      other.path == path &&
      other.readOnly == readOnly;

  @override
  int get hashCode => Object.hash(path, readOnly);
}

/// The Display tab.
@immutable
class PcDisplaySettings {
  const PcDisplaySettings({
    this.resolution = Resolution.fullHd,
    this.displayMode = DisplayMode.allDisplays,
    this.startFullScreen = false,
    this.fitSessionToWindow = false,
    this.updateResolutionOnResize = true,
    this.colorDepth = 32,
  });

  final Resolution resolution;
  final DisplayMode displayMode;
  final bool startFullScreen;
  final bool fitSessionToWindow;

  /// When true the remote desktop follows the window size, which makes
  /// [resolution] a starting point rather than a fixed choice. The form greys
  /// out the resolution picker in that case, as the app does.
  final bool updateResolutionOnResize;

  /// Bits per pixel: 32, 24 or 16.
  final int colorDepth;

  PcDisplaySettings copyWith({
    Resolution? resolution,
    DisplayMode? displayMode,
    bool? startFullScreen,
    bool? fitSessionToWindow,
    bool? updateResolutionOnResize,
    int? colorDepth,
  }) => PcDisplaySettings(
    resolution: resolution ?? this.resolution,
    displayMode: displayMode ?? this.displayMode,
    startFullScreen: startFullScreen ?? this.startFullScreen,
    fitSessionToWindow: fitSessionToWindow ?? this.fitSessionToWindow,
    updateResolutionOnResize:
        updateResolutionOnResize ?? this.updateResolutionOnResize,
    colorDepth: colorDepth ?? this.colorDepth,
  );

  Map<String, Object?> toJson() => {
    'resolution': {'width': resolution.width, 'height': resolution.height},
    'displayMode': displayMode.name,
    'startFullScreen': startFullScreen,
    'fitSessionToWindow': fitSessionToWindow,
    'updateResolutionOnResize': updateResolutionOnResize,
    'colorDepth': colorDepth,
  };

  factory PcDisplaySettings.fromJson(Map<String, Object?> json) {
    final resolution = asMapOrEmpty(json['resolution']);
    return PcDisplaySettings(
      resolution: Resolution(
        asInt(resolution['width'], Resolution.fullHd.width),
        asInt(resolution['height'], Resolution.fullHd.height),
      ),
      displayMode: DisplayMode.fromName(asStringOrNull(json['displayMode'])),
      startFullScreen: asBool(json['startFullScreen'], false),
      fitSessionToWindow: asBool(json['fitSessionToWindow'], false),
      updateResolutionOnResize: asBool(json['updateResolutionOnResize'], true),
      colorDepth: asInt(json['colorDepth'], 32),
    );
  }
}

/// The Devices & Audio and Folders tabs.
@immutable
class PcRedirectionSettings {
  const PcRedirectionSettings({
    this.clipboardMode = ClipboardMode.bidirectional,
    this.audioPlayback = AudioPlaybackMode.onThisComputer,
    this.redirectPrinters = false,
    this.redirectSmartCards = true,
    this.redirectDrives = false,
    this.redirectMicrophone = false,
    this.redirectCamera = false,
    this.folders = const [],
  });

  final ClipboardMode clipboardMode;
  final AudioPlaybackMode audioPlayback;
  final bool redirectPrinters;
  final bool redirectSmartCards;
  final bool redirectDrives;
  final bool redirectMicrophone;
  final bool redirectCamera;
  final List<RedirectedFolder> folders;

  PcRedirectionSettings copyWith({
    ClipboardMode? clipboardMode,
    AudioPlaybackMode? audioPlayback,
    bool? redirectPrinters,
    bool? redirectSmartCards,
    bool? redirectDrives,
    bool? redirectMicrophone,
    bool? redirectCamera,
    List<RedirectedFolder>? folders,
  }) => PcRedirectionSettings(
    clipboardMode: clipboardMode ?? this.clipboardMode,
    audioPlayback: audioPlayback ?? this.audioPlayback,
    redirectPrinters: redirectPrinters ?? this.redirectPrinters,
    redirectSmartCards: redirectSmartCards ?? this.redirectSmartCards,
    redirectDrives: redirectDrives ?? this.redirectDrives,
    redirectMicrophone: redirectMicrophone ?? this.redirectMicrophone,
    redirectCamera: redirectCamera ?? this.redirectCamera,
    folders: folders ?? this.folders,
  );

  Map<String, Object?> toJson() => {
    'clipboardMode': clipboardMode.name,
    'audioPlayback': audioPlayback.name,
    'redirectPrinters': redirectPrinters,
    'redirectSmartCards': redirectSmartCards,
    'redirectDrives': redirectDrives,
    'redirectMicrophone': redirectMicrophone,
    'redirectCamera': redirectCamera,
    'folders': folders.map((folder) => folder.toJson()).toList(),
  };

  factory PcRedirectionSettings.fromJson(Map<String, Object?> json) =>
      PcRedirectionSettings(
        clipboardMode: ClipboardMode.fromName(
          asStringOrNull(json['clipboardMode']),
        ),
        audioPlayback: AudioPlaybackMode.fromName(
          asStringOrNull(json['audioPlayback']),
        ),
        redirectPrinters: asBool(json['redirectPrinters'], false),
        redirectSmartCards: asBool(json['redirectSmartCards'], true),
        redirectDrives: asBool(json['redirectDrives'], false),
        redirectMicrophone: asBool(json['redirectMicrophone'], false),
        redirectCamera: asBool(json['redirectCamera'], false),
        folders: asList(json['folders'])
            .whereType<Map<String, Object?>>()
            .map(RedirectedFolder.fromJson)
            .toList(),
      );
}

@immutable
class PcConnection {
  const PcConnection({
    required this.id,
    required this.hostname,
    this.friendlyName = '',
    this.port = defaultPort,
    this.group = '',
    this.credentialMode = CredentialMode.askEveryTime,
    this.credentialId,
    this.gatewayId,
    this.reconnectIfDropped = true,
    this.adminSession = false,
    this.swapMouseButtons = false,
    this.display = const PcDisplaySettings(),
    this.redirection = const PcRedirectionSettings(),
    this.favorite = false,
    this.lastConnectedAt,
    this.createdAt,
  });

  static const int defaultPort = 3389;

  final String id;

  /// The PC name as typed: a host name or IP, optionally with `:port`.
  final String hostname;

  /// The user-visible name. Falls back to [hostname] when empty.
  final String friendlyName;

  final int port;

  /// Optional grouping label used by the connection centre.
  final String group;

  final CredentialMode credentialMode;
  final String? credentialId;
  final String? gatewayId;

  final bool reconnectIfDropped;

  /// Connect to the console/admin session (`/admin`).
  final bool adminSession;

  final bool swapMouseButtons;

  final PcDisplaySettings display;
  final PcRedirectionSettings redirection;

  /// Pinned to the Favorites tab.
  final bool favorite;

  /// Drives the "recently used" sort order.
  final DateTime? lastConnectedAt;

  final DateTime? createdAt;

  String get displayName => friendlyName.isNotEmpty ? friendlyName : hostname;

  /// [port], unless [hostname] already carries an explicit one.
  int get effectivePort => splitHostPort(hostname).port ?? port;

  /// [hostname] with any embedded port removed, ready for the RDP settings.
  String get effectiveHostname => splitHostPort(hostname).hostname;

  bool get usesGateway => gatewayId != null;

  PcConnection copyWith({
    String? hostname,
    String? friendlyName,
    int? port,
    String? group,
    CredentialMode? credentialMode,
    String? credentialId,
    bool clearCredentialId = false,
    String? gatewayId,
    bool clearGatewayId = false,
    bool? reconnectIfDropped,
    bool? adminSession,
    bool? swapMouseButtons,
    PcDisplaySettings? display,
    PcRedirectionSettings? redirection,
    bool? favorite,
    DateTime? lastConnectedAt,
  }) => PcConnection(
    id: id,
    hostname: hostname ?? this.hostname,
    friendlyName: friendlyName ?? this.friendlyName,
    port: port ?? this.port,
    group: group ?? this.group,
    credentialMode: credentialMode ?? this.credentialMode,
    credentialId: clearCredentialId
        ? null
        : (credentialId ?? this.credentialId),
    gatewayId: clearGatewayId ? null : (gatewayId ?? this.gatewayId),
    reconnectIfDropped: reconnectIfDropped ?? this.reconnectIfDropped,
    adminSession: adminSession ?? this.adminSession,
    swapMouseButtons: swapMouseButtons ?? this.swapMouseButtons,
    display: display ?? this.display,
    redirection: redirection ?? this.redirection,
    favorite: favorite ?? this.favorite,
    lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'hostname': hostname,
    'friendlyName': friendlyName,
    'port': port,
    'group': group,
    'credentialMode': credentialMode.name,
    'credentialId': credentialId,
    'gatewayId': gatewayId,
    'reconnectIfDropped': reconnectIfDropped,
    'adminSession': adminSession,
    'swapMouseButtons': swapMouseButtons,
    'display': display.toJson(),
    'redirection': redirection.toJson(),
    'favorite': favorite,
    'lastConnectedAt': lastConnectedAt?.toIso8601String(),
    'createdAt': createdAt?.toIso8601String(),
  };

  factory PcConnection.fromJson(Map<String, Object?> json) => PcConnection(
    // The one field with no sensible default; a record without it is not a
    // connection at all, so failing loudly here is correct.
    id: json['id']! as String,
    hostname: asString(json['hostname']),
    friendlyName: asString(json['friendlyName']),
    port: asInt(json['port'], defaultPort),
    group: asString(json['group']),
    credentialMode: CredentialMode.fromName(
      asStringOrNull(json['credentialMode']),
    ),
    credentialId: asStringOrNull(json['credentialId']),
    gatewayId: asStringOrNull(json['gatewayId']),
    reconnectIfDropped: asBool(json['reconnectIfDropped'], true),
    adminSession: asBool(json['adminSession'], false),
    swapMouseButtons: asBool(json['swapMouseButtons'], false),
    display: PcDisplaySettings.fromJson(asMapOrEmpty(json['display'])),
    redirection: PcRedirectionSettings.fromJson(
      asMapOrEmpty(json['redirection']),
    ),
    favorite: asBool(json['favorite'], false),
    lastConnectedAt: asDateOrNull(json['lastConnectedAt']),
    createdAt: asDateOrNull(json['createdAt']),
  );

  @override
  bool operator ==(Object other) => other is PcConnection && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PcConnection($id, $displayName)';
}
