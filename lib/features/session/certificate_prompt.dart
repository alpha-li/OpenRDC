/// Asks whether to trust a certificate the host presented.
///
/// The session thread is blocked while this is open, so the dialog cannot be
/// dismissed by clicking away, and closing it — Esc, the window's close button —
/// is treated as a refusal rather than as silence. Leaving it unanswered would
/// otherwise stall the connection until the native side gives up a minute later.
library;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../engine/rdc_engine.dart';
import '../../theme/fluent_colors.dart';
import '../../l10n/generated/app_localizations.dart';

class CertificatePrompt extends StatefulWidget {
  const CertificatePrompt({super.key, required this.certificate});

  final RdcCertificate certificate;

  @override
  State<CertificatePrompt> createState() => _CertificatePromptState();
}

class _CertificatePromptState extends State<CertificatePrompt> {
  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final certificate = widget.certificate;

    // Three situations that look alike and mean different things. Describing
    // them with one message would either cry wolf on every new host or, worse,
    // play down the one case that indicates interception.
    final (
      String headline,
      String? warning,
      Color accent,
    ) = switch (certificate) {
      _ when certificate.changed => (
        AppLocalizations.of(context).certificateChangedTitle,
        AppLocalizations.of(context).certificateChangedBody,
        colors.systemFillColorCritical,
      ),
      _ when certificate.nameMismatch => (
        AppLocalizations.of(context).certificateNameMismatchTitle,
        AppLocalizations.of(context).certificateNameMismatchBody,
        colors.systemFillColorCritical,
      ),
      _ => (
        AppLocalizations.of(context).certificateUntrustedTitle,
        null,
        colors.systemFillColorCaution,
      ),
    };

    return PopScope(
      // Dismissing is a decision, not a no-op: the connection is waiting.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(RdcCertificateDecision.reject);
        }
      },
      child: AlertDialog(
        backgroundColor: colors.solidBackgroundFillColorTertiary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Row(
          children: [
            Icon(FluentIcons.shield_error_24_regular, size: 20, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                headline,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colors.textFillColorPrimary,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (warning != null) ...[
                  _Warning(colors: colors, accent: accent, text: warning),
                  const SizedBox(height: 16),
                ],
                _Row(
                  label: AppLocalizations.of(context).certificateRequestedHost,
                  value: '${certificate.host}:${certificate.port}',
                  colors: colors,
                ),
                _Row(
                  label: AppLocalizations.of(context).certificateName,
                  value: certificate.commonName.isEmpty
                      ? AppLocalizations.of(context).certificateNoName
                      : certificate.commonName,
                  colors: colors,
                  emphasise: certificate.nameMismatch,
                ),
                if (certificate.issuer.isNotEmpty)
                  _Row(
                    label: AppLocalizations.of(context).certificateIssuer,
                    value: certificate.issuer,
                    colors: colors,
                  ),
                if (certificate.changed &&
                    certificate.oldFingerprint.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _Row(
                    label: AppLocalizations.of(
                      context,
                    ).certificatePreviousFingerprint,
                    value: certificate.oldFingerprint,
                    colors: colors,
                    monospace: true,
                  ),
                ],
                const SizedBox(height: 8),
                _Row(
                  label: certificate.changed
                      ? AppLocalizations.of(
                          context,
                        ).certificateCurrentFingerprint
                      : AppLocalizations.of(context).certificateFingerprint,
                  value: certificate.fingerprint.isEmpty
                      ? AppLocalizations.of(context).certificateNone
                      : certificate.fingerprint,
                  colors: colors,
                  monospace: true,
                  emphasise: certificate.changed,
                ),
                const SizedBox(height: 16),
                Text(
                  certificate.changed
                      ? AppLocalizations.of(context).certificateAcceptChanged
                      : AppLocalizations.of(
                          context,
                        ).certificateAcceptRemembered,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    color: colors.textFillColorTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(RdcCertificateDecision.reject),
            child: Text(AppLocalizations.of(context).no),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(RdcCertificateDecision.acceptAndStore),
            style: FilledButton.styleFrom(
              backgroundColor: colors.accentFillColorDefault,
              foregroundColor: colors.textOnAccentFillColorPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text(AppLocalizations.of(context).yes),
          ),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({
    required this.colors,
    required this.accent,
    required this.text,
  });

  final FluentColors colors;
  final Color accent;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cardBackgroundFillColorDefault,
        border: Border.all(color: accent),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          color: colors.textFillColorPrimary,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.colors,
    this.monospace = false,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final FluentColors colors;
  final bool monospace;

  /// Draws attention to the value, used for the fingerprint that matters.
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              color: colors.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: monospace ? 12 : 14,
              height: monospace ? 18 / 12 : 20 / 14,
              fontFamily: monospace ? 'Consolas' : null,
              fontWeight: emphasise ? FontWeight.w600 : FontWeight.w400,
              color: emphasise
                  ? colors.systemFillColorCritical
                  : colors.textFillColorPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience for callers that want to ask and await an answer.
Future<int> showCertificatePrompt(
  BuildContext context,
  RdcCertificate certificate,
) async {
  final decision = await showDialog<int>(
    context: context,
    // The connection is blocked on this answer, so a stray click outside must
    // not be able to leave it unanswered.
    barrierDismissible: false,
    builder: (context) => CertificatePrompt(certificate: certificate),
  );
  return decision ?? RdcCertificateDecision.reject;
}
