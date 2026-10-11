/// A Remote Desktop Gateway (RD Gateway) a connection can be routed through.
///
/// Gateways are stored once and referenced by connections, mirroring the way
/// the Windows App lets one gateway be shared across many PCs.
library;

import 'package:flutter/foundation.dart';

import 'credential.dart';
import 'json_utils.dart';

@immutable
class Gateway {
  const Gateway({
    required this.id,
    required this.hostname,
    this.friendlyName = '',
    this.port = defaultPort,
    this.credentialMode = CredentialMode.askEveryTime,
    this.credentialId,
    this.bypassForLocalAddresses = true,
  });

  /// Gateways always speak over TLS, so the default is 443 rather than 3389.
  static const int defaultPort = 443;

  final String id;

  /// Host name or IP of the gateway. May include an explicit port, which
  /// [effectivePort] prefers over [port].
  final String hostname;

  final String friendlyName;
  final int port;

  final CredentialMode credentialMode;

  /// The [Credential] to use, or null to reuse the PC's own credentials. That
  /// is the "use PC credential" option in the app, and it is the common case.
  final String? credentialId;

  final bool bypassForLocalAddresses;

  /// What to show in lists: the friendly name when there is one, else the host.
  String get displayName => friendlyName.isNotEmpty ? friendlyName : hostname;

  /// Reuses the PC's credential rather than naming its own.
  bool get usesPcCredential => credentialId == null;

  /// [port], unless [hostname] already carries one.
  int get effectivePort => splitHostPort(hostname).port ?? port;

  /// [hostname] with any embedded port stripped.
  String get effectiveHostname => splitHostPort(hostname).hostname;

  Gateway copyWith({
    String? hostname,
    String? friendlyName,
    int? port,
    CredentialMode? credentialMode,
    String? credentialId,
    bool clearCredentialId = false,
    bool? bypassForLocalAddresses,
  }) => Gateway(
    id: id,
    hostname: hostname ?? this.hostname,
    friendlyName: friendlyName ?? this.friendlyName,
    port: port ?? this.port,
    credentialMode: credentialMode ?? this.credentialMode,
    credentialId: clearCredentialId
        ? null
        : (credentialId ?? this.credentialId),
    bypassForLocalAddresses:
        bypassForLocalAddresses ?? this.bypassForLocalAddresses,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'hostname': hostname,
    'friendlyName': friendlyName,
    'port': port,
    'credentialMode': credentialMode.name,
    'credentialId': credentialId,
    'bypassForLocalAddresses': bypassForLocalAddresses,
  };

  factory Gateway.fromJson(Map<String, Object?> json) => Gateway(
    id: json['id']! as String,
    hostname: asString(json['hostname']),
    friendlyName: asString(json['friendlyName']),
    port: asInt(json['port'], defaultPort),
    credentialMode: CredentialMode.fromName(
      asStringOrNull(json['credentialMode']),
    ),
    credentialId: asStringOrNull(json['credentialId']),
    bypassForLocalAddresses: asBool(json['bypassForLocalAddresses'], true),
  );

  @override
  bool operator ==(Object other) => other is Gateway && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Gateway($id, $displayName)';
}
