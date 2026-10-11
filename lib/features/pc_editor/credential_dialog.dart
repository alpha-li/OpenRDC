/// Create a saved credential.
///
/// Mirrors the app's "Add Saved Credential" sheet: a user name, a password and
/// an optional friendly name. The password is handed to a [CredentialVault] and
/// is never part of the returned [Credential], so it cannot end up in the
/// connection file.
library;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../data/credential_vault.dart';
import '../../data/ids.dart';
import '../../models/credential.dart';
import '../../theme/fluent_colors.dart';
import '../../widgets/fluent_controls.dart';
import '../../l10n/generated/app_localizations.dart';

class CredentialDialog extends StatefulWidget {
  const CredentialDialog({super.key, required this.vault, this.existing});

  /// Where the password is stored.
  ///
  /// Required, deliberately. It used to default to a fresh
  /// [MemoryCredentialVault], which meant a caller that forgot to pass one got a
  /// dialog that appeared to save the password into a temporary map and threw it
  /// away when it closed -- so the user was prompted for the same password
  /// forever, which is precisely what saved credentials exist to avoid. Making
  /// it required turns that into a compile error.
  final CredentialVault vault;

  final Credential? existing;

  @override
  State<CredentialDialog> createState() => _CredentialDialogState();
}

class _CredentialDialogState extends State<CredentialDialog> {
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _friendlyName;

  CredentialVault get _vault => widget.vault;
  bool _obscure = true;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.existing?.username ?? '');
    _password = TextEditingController();
    _friendlyName = TextEditingController(
      text: widget.existing?.friendlyName ?? '',
    );
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _friendlyName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _username.text.trim();
    if (username.isEmpty) {
      setState(
        () => _usernameError = AppLocalizations.of(
          context,
        ).validationUsernameRequired,
      );
      return;
    }

    final id = widget.existing?.id ?? newId();
    final password = _password.text;
    if (password.isNotEmpty) {
      await _vault.store(id, password);
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(
      Credential(
        id: id,
        friendlyName: _friendlyName.text.trim(),
        username: username,
        // `domain\user` and `user@domain` are both accepted on entry; only the
        // backslash form names a domain here, since the at-sign form carries it
        // in the user name itself.
        domain: _splitDomain(username).domain,
      ),
    );
  }

  static ({String username, String domain}) _splitDomain(String raw) {
    final backslash = raw.indexOf(r'\');
    if (backslash > 0) {
      return (
        domain: raw.substring(0, backslash),
        username: raw.substring(backslash + 1),
      );
    }
    return (username: raw, domain: '');
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);

    return AlertDialog(
      backgroundColor: colors.solidBackgroundFillColorTertiary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        widget.existing == null
            ? AppLocalizations.of(context).newCredential
            : AppLocalizations.of(context).editCredential,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.textFillColorPrimary,
        ),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Labelled(
              label: AppLocalizations.of(context).credentialUsername,
              child: FluentTextField(
                controller: _username,
                placeholder: AppLocalizations.of(
                  context,
                ).credentialUsernamePlaceholder,
                errorText: _usernameError,
                onChanged: (_) {
                  if (_usernameError != null) {
                    setState(() => _usernameError = null);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            _Labelled(
              label: AppLocalizations.of(context).credentialPassword,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: kFluentControlHeight,
                      child: TextField(
                        controller: _password,
                        obscureText: _obscure,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textFillColorPrimary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          filled: true,
                          fillColor: colors.controlFillColorDefault,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              kFluentControlRadius,
                            ),
                            borderSide: BorderSide(
                              color: colors.controlStrokeColorDefault,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              kFluentControlRadius,
                            ),
                            borderSide: BorderSide(
                              color: colors.controlStrokeColorDefault,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? FluentIcons.eye_24_regular
                          : FluentIcons.eye_off_24_regular,
                      size: 16,
                    ),
                    tooltip: _obscure
                        ? AppLocalizations.of(context).showPassword
                        : AppLocalizations.of(context).hidePassword,
                    color: colors.textFillColorSecondary,
                  ),
                ],
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
            if (!_vault.isPersistent) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    FluentIcons.warning_24_regular,
                    size: 16,
                    color: colors.systemFillColorCaution,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).vaultNotPersistentWarning,
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        color: colors.textFillColorSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
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
          child: Text(AppLocalizations.of(context).add),
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
