import 'dart:io';

import 'package:flutter/material.dart';

import 'app.dart';

/// Command-line switches, all optional.
///
///   `--diagnostics`          native bridge self-check instead of the UI
///   `--connect host[:port]`  open a session immediately, skipping the UI.
///                            A session that fails ends the process with a
///                            non-zero code, there being no UI to fall back to
///   `--user name`            user name for `--connect` (may be `DOMAIN\user`)
///   `--domain name`          domain for `--connect`
///   `--fullscreen`           start the session full screen
///   `--ignore-cert`          skip the certificate prompt for this connection
///
/// The password for --connect comes from the OPENRDC_PASSWORD environment
/// variable rather than an argument, so it does not appear in the process list
/// where any other process could read it.
void main(List<String> args) {
  runApp(
    OpenRdcApp(
      startup: _parseStartup(args),
      // Only the `--connect` launch has a use for this, and only when it fails:
      // that page is the application's root, so there is no connection centre
      // standing by to return to. Non-zero, so a script driving `--connect` can
      // tell a failed session from a finished one.
      onExit: () => exit(1),
    ),
  );
}

StartupMode _parseStartup(List<String> args) {
  if (args.contains('--diagnostics')) {
    return const DiagnosticsStartup();
  }

  final index = args.indexOf('--connect');
  if (index < 0 || index + 1 >= args.length) {
    return const ConnectionCentreStartup();
  }

  final (hostname, port) = _splitHostPort(args[index + 1]);
  final rawUser = _valueAfter(args, '--user') ?? '';
  final (username, embeddedDomain) = _splitDomain(rawUser);

  return DirectConnectStartup(
    hostname: hostname,
    port: port,
    username: username,
    password: Platform.environment['OPENRDC_PASSWORD'] ?? '',
    domain: _valueAfter(args, '--domain') ?? embeddedDomain,
    startFullScreen: args.contains('--fullscreen'),
    // Off unless asked for: the prompt is the only thing between the user and a
    // silently intercepted session, so skipping it has to be deliberate.
    ignoreCertificate: args.contains('--ignore-cert'),
  );
}

String? _valueAfter(List<String> args, String flag) {
  final index = args.indexOf(flag);
  if (index < 0 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}

/// Splits `host`, `host:port` or `[ipv6]:port`.
(String, int) _splitHostPort(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('[')) {
    final closing = trimmed.indexOf(']');
    if (closing > 0) {
      final host = trimmed.substring(1, closing);
      final rest = trimmed.substring(closing + 1);
      if (rest.startsWith(':')) {
        return (host, int.tryParse(rest.substring(1)) ?? 3389);
      }
      return (host, 3389);
    }
  }
  final colon = trimmed.lastIndexOf(':');
  if (colon > 0) {
    final port = int.tryParse(trimmed.substring(colon + 1));
    if (port != null) {
      return (trimmed.substring(0, colon), port);
    }
  }
  return (trimmed, 3389);
}

(String, String) _splitDomain(String raw) {
  final backslash = raw.indexOf(r'\');
  if (backslash > 0) {
    return (raw.substring(backslash + 1), raw.substring(0, backslash));
  }
  return (raw, '');
}
