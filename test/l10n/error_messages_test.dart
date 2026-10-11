import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openrdc/l10n/error_messages.dart';
import 'package:openrdc/l10n/generated/app_localizations.dart';
import 'package:rdc_bridge/rdc_bridge.dart' as bridge;

void main() {
  /// The mapper needs an AppLocalizations, which needs a locale. Building one
  /// directly keeps these tests out of the widget layer.
  late AppLocalizations zh;
  late AppLocalizations en;

  setUpAll(() async {
    zh = await AppLocalizations.delegate.load(const Locale('zh'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('rdcErrorMessage', () {
    test('explains the failures a user can act on', () {
      expect(
        rdcErrorMessage(zh, bridge.RdcResult.errConnectFailed, fallback: 'x'),
        zh.errorConnectFailed,
      );
      expect(
        rdcErrorMessage(zh, bridge.RdcResult.errAuthFailed, fallback: 'x'),
        zh.errorAuthFailed,
      );
      expect(
        rdcErrorMessage(zh, bridge.RdcResult.errNoCredentials, fallback: 'x'),
        zh.errorNoCredentials,
      );
      expect(
        rdcErrorMessage(zh, bridge.RdcResult.errTlsFailed, fallback: 'x'),
        zh.errorTlsFailed,
      );
    });

    test('collapses engine-internal failures into one sentence', () {
      // Which internal step failed is worth a log line and nothing more: the
      // user can only retry, so telling them apart would be noise dressed up as
      // information.
      for (final code in [
        bridge.RdcResult.errSessionContext,
        bridge.RdcResult.errSessionStart,
        bridge.RdcResult.errGdiInit,
        bridge.RdcResult.errEventHandles,
        bridge.RdcResult.errEventWait,
        bridge.RdcResult.errNotImplemented,
        bridge.RdcResult.errPlatform,
      ]) {
        expect(rdcErrorMessage(zh, code, fallback: 'x'), zh.errorInternal);
      }
    });

    test('returns null for a code it does not know', () {
      // Null rather than a guess, so the caller keeps the engine's own
      // description instead of being handed a confident-sounding wrong answer.
      expect(rdcErrorMessage(zh, 12345, fallback: 'x'), isNull);
      expect(rdcErrorMessage(zh, 0, fallback: 'x'), isNull);
    });

    test('gives a different sentence in each language', () {
      final message = rdcErrorMessage(
        en,
        bridge.RdcResult.errConnectFailed,
        fallback: 'x',
      );
      expect(message, en.errorConnectFailed);
      expect(message, isNot(zh.errorConnectFailed));
    });

    test('never returns the fallback itself', () {
      // The fallback belongs to the caller. If the mapper ever returned it, a
      // missing translation would look identical to an unrecognised code and
      // the difference would be invisible.
      const sentinel = 'ENGINE DETAIL SENTINEL';
      for (final code in [
        bridge.RdcResult.errConnectFailed,
        bridge.RdcResult.errAuthFailed,
        12345,
      ]) {
        expect(rdcErrorMessage(zh, code, fallback: sentinel), isNot(sentinel));
      }
    });
  });
}
