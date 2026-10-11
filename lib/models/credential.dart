/// A named account used to sign in to a PC or a gateway.
///
/// Note the deliberate split: a [Credential] is a *device* credential for RDP
/// sign-in, which is a different concept from the work/school *account* used to
/// subscribe to workspaces. The Windows App keeps them separate and so do we;
/// merging them would make "ask me every time" impossible to express.
///
/// The password is never held here. It lives in the platform credential vault
/// and is fetched on demand, so that persisting connections cannot leak it.
library;

import 'package:flutter/foundation.dart';

import 'json_utils.dart';

@immutable
class Credential {
  const Credential({
    required this.id,
    required this.friendlyName,
    required this.username,
    this.domain = '',
  });

  /// Stable identifier referenced by [PcConnection] and [Gateway].
  final String id;

  /// Label shown in the credential picker.
  final String friendlyName;

  /// Either `user` or `user@domain`. Kept as entered so the user can see what
  /// was typed; [domain] is carried separately for the RDP domain field.
  final String username;

  final String domain;

  /// The `DOMAIN\user` form the RDP protocol wants, or just the username when
  /// no domain was given.
  String get qualifiedUsername =>
      domain.isEmpty ? username : '$domain\\$username';

  Credential copyWith({
    String? friendlyName,
    String? username,
    String? domain,
  }) => Credential(
    id: id,
    friendlyName: friendlyName ?? this.friendlyName,
    username: username ?? this.username,
    domain: domain ?? this.domain,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'friendlyName': friendlyName,
    'username': username,
    'domain': domain,
  };

  factory Credential.fromJson(Map<String, Object?> json) => Credential(
    id: json['id']! as String,
    friendlyName: asString(json['friendlyName']),
    username: asString(json['username']),
    domain: asString(json['domain']),
  );

  @override
  bool operator ==(Object other) => other is Credential && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Credential($id, $friendlyName)';
}

/// How a connection should obtain its sign-in credentials.
enum CredentialMode {
  /// Prompt every time; nothing is stored.
  askEveryTime,

  /// Use a saved [Credential] by id.
  saved;

  static CredentialMode fromName(String? name) =>
      CredentialMode.values.firstWhere(
        (mode) => mode.name == name,
        orElse: () => CredentialMode.askEveryTime,
      );
}
