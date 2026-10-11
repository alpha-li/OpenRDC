/// Localised labels for the enums the engine layer defines.
///
/// The engine has no BuildContext -- it is a platform layer, and its enums are
/// constructed at compile time -- so the words for its states live here, next
/// to the translations, rather than on the enums themselves. That keeps the
/// engine free of presentation concerns and keeps the strings somewhere a
/// translator can find them.
library;

import '../engine/rdc_engine.dart';
import 'generated/app_localizations.dart';

extension RdcSessionStatusLabel on RdcSessionStatus {
  /// What to show the user for this state.
  String label(AppLocalizations l10n) => switch (this) {
    RdcSessionStatus.idle => l10n.statusIdle,
    RdcSessionStatus.connecting => l10n.statusConnecting,
    RdcSessionStatus.authenticating => l10n.statusAuthenticating,
    RdcSessionStatus.connected => l10n.statusConnected,
    RdcSessionStatus.disconnecting => l10n.statusDisconnecting,
    RdcSessionStatus.disconnected => l10n.statusDisconnected,
    RdcSessionStatus.failed => l10n.statusFailed,
  };
}
