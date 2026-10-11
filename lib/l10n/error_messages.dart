/// Turns the engine's error codes into sentences.
///
/// The native layer reports a stable category, not a sentence: a sentence
/// written there would arrive as a `String` with no way back to a translation,
/// and would be in whatever language the C++ happened to use. Codes cross the
/// boundary; words are chosen here.
///
/// The engine's own description is kept as the fallback rather than discarded.
/// It is English and aimed at a developer, but for a failure this table does not
/// recognise, showing it beats showing nothing.
library;

import 'package:rdc_bridge/rdc_bridge.dart' as bridge;

import 'generated/app_localizations.dart';

/// The sentence to show for [code], or null when the code is not one this table
/// recognises — in which case the caller should fall back to [fallback].
String? rdcErrorMessage(
  AppLocalizations l10n,
  int code, {
  required String fallback,
}) {
  // The result codes are negative and shared by every entry point.
  return switch (code) {
    bridge.RdcResult.errConnectFailed => l10n.errorConnectFailed,
    bridge.RdcResult.errTlsFailed => l10n.errorTlsFailed,
    bridge.RdcResult.errPasswordExpired => l10n.errorPasswordExpired,
    bridge.RdcResult.errAuthFailed => l10n.errorAuthFailed,
    bridge.RdcResult.errNoCredentials => l10n.errorNoCredentials,
    bridge.RdcResult.errAlreadyRunning => l10n.errorAlreadyRunning,

    // Everything below means the engine itself could not get going, which the
    // user can do nothing about beyond retrying — so they are told that, not
    // which internal step failed.
    bridge.RdcResult.errSessionContext ||
    bridge.RdcResult.errSessionStart ||
    bridge.RdcResult.errGdiInit ||
    bridge.RdcResult.errEventHandles ||
    bridge.RdcResult.errEventWait ||
    bridge.RdcResult.errNotImplemented ||
    bridge.RdcResult.errPlatform ||
    bridge.RdcResult.errNoTextureRegistrar => l10n.errorInternal,

    bridge.RdcResult.errBadArgument => l10n.errorSessionStart,

    _ => null,
  };
}
