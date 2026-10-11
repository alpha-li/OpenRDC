/// Create or edit a Remote Desktop Gateway.
///
/// The form is short because a gateway is a small thing: an address, a friendly
/// name, and how to authenticate to it. The "same as the PC" option is the
/// default because that is what the protocol expects -- FreeRDP has a dedicated
/// setting for it, and making the user re-type credentials the gateway is
/// usually configured to accept from the session anyway would be noise.
library;

import 'package:flutter/material.dart';

import '../../data/connection_store.dart';
import '../../data/ids.dart';
import '../../models/credential.dart';
import '../../models/gateway.dart';
import '../../theme/fluent_colors.dart';
import '../../widgets/fluent_controls.dart';
import '../../l10n/generated/app_localizations.dart';

class GatewayDialog extends StatefulWidget {
  const GatewayDialog({super.key, required this.store, this.existing});

  final ConnectionStore store;
  final Gateway? existing;

  @override
  State<GatewayDialog> createState() => _GatewayDialogState();
}

class _GatewayDialogState extends State<GatewayDialog> {
  /// Sentinel for "no credential of its own".
  static const String _sameAsPc = '\u0000pc';

  late final TextEditingController _hostname = TextEditingController(
    text: widget.existing?.hostname ?? '',
  );
  late final TextEditingController _friendlyName = TextEditingController(
    text: widget.existing?.friendlyName ?? '',
  );
  late final TextEditingController _port = TextEditingController(
    text: '${widget.existing?.port ?? Gateway.defaultPort}',
  );

  late String _credentialId = widget.existing?.credentialId ?? _sameAsPc;
  late bool _bypassLocal = widget.existing?.bypassForLocalAddresses ?? true;

  String? _hostnameError;

  @override
  void dispose() {
    _hostname.dispose();
    _friendlyName.dispose();
    _port.dispose();
    super.dispose();
  }

  void _save() {
    final hostname = _hostname.text.trim();
    if (hostname.isEmpty) {
      setState(
        () => _hostnameError = AppLocalizations.of(
          context,
        ).validationGatewayRequired,
      );
      return;
    }

    final existing = widget.existing;
    Navigator.of(context).pop(
      Gateway(
        id: existing?.id ?? newId(),
        hostname: hostname,
        friendlyName: _friendlyName.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? Gateway.defaultPort,
        // No credential of its own is expressed as "ask every time" with no id;
        // the session layer reads that as "reuse the PC's credentials", which is
        // what the protocol's UseSameCredentials setting means.
        credentialMode: _credentialId == _sameAsPc
            ? CredentialMode.askEveryTime
            : CredentialMode.saved,
        credentialId: _credentialId == _sameAsPc ? null : _credentialId,
        bypassForLocalAddresses: _bypassLocal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final credentials = widget.store.credentials;

    return AlertDialog(
      backgroundColor: colors.solidBackgroundFillColorTertiary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        widget.existing == null
            ? AppLocalizations.of(context).newGateway
            : AppLocalizations.of(context).editGateway,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.textFillColorPrimary,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Labelled(
                label: AppLocalizations.of(context).gatewayAddress,
                child: FluentTextField(
                  controller: _hostname,
                  placeholder: AppLocalizations.of(
                    context,
                  ).gatewayAddressPlaceholder,
                  errorText: _hostnameError,
                  onChanged: (_) {
                    if (_hostnameError != null) {
                      setState(() => _hostnameError = null);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              _Labelled(
                label: AppLocalizations.of(context).fieldFriendlyName,
                child: FluentTextField(
                  controller: _friendlyName,
                  placeholder: AppLocalizations.of(
                    context,
                  ).credentialFriendlyNamePlaceholder,
                ),
              ),
              const SizedBox(height: 12),
              _Labelled(
                label: AppLocalizations.of(context).fieldPort,
                child: FluentTextField(
                  controller: _port,
                  placeholder: '${Gateway.defaultPort}',
                  maxWidth: 140,
                ),
              ),
              const SizedBox(height: 12),
              _Labelled(
                label: AppLocalizations.of(context).gatewayCredentials,
                child: FluentDropdown<String>(
                  value: _credentialId,
                  items: [
                    (_sameAsPc, AppLocalizations.of(context).gatewaySameAsPc),
                    for (final credential in credentials)
                      (
                        credential.id,
                        credential.friendlyName.isEmpty
                            ? credential.qualifiedUsername
                            : credential.friendlyName,
                      ),
                  ],
                  onChanged: (value) => setState(() => _credentialId = value),
                ),
              ),
              const SizedBox(height: 12),
              FluentCheckbox(
                label: AppLocalizations.of(context).fieldBypassGateway,
                description: AppLocalizations.of(
                  context,
                ).fieldBypassGatewayBody,
                value: _bypassLocal,
                onChanged: (value) => setState(() => _bypassLocal = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: colors.accentFillColorDefault,
            foregroundColor: colors.textOnAccentFillColorPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Text(AppLocalizations.of(context).save),
        ),
      ],
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: colors.textFillColorPrimary,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
