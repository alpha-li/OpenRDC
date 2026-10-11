/// Asks the user for the credentials a session needs.
///
/// Shown when a connection is configured to ask every time, and whenever a
/// saved credential exists but has no password stored against it.
library;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../theme/fluent_colors.dart';
import '../../widgets/fluent_controls.dart';
import '../../l10n/generated/app_localizations.dart';

/// The values the prompt collected.
///
/// [remember] asks for the password to be saved to the platform secret store.
/// It is only ever offered when there is a credential record to save it
/// against, so the caller can rely on it being false otherwise.
typedef EnteredCredentials = ({
  String username,
  String password,
  String domain,
  bool remember,
});

class CredentialPrompt extends StatefulWidget {
  const CredentialPrompt({
    super.key,
    required this.title,
    this.initialUsername = '',
    this.message,
    this.vaultIsPersistent = false,
    this.canRemember = false,
  });

  /// What the credentials are for, e.g. the PC name.
  final String title;

  final String initialUsername;

  /// Optional explanation shown above the fields, for reconnect prompts.
  final String? message;

  /// Whether a saved password would actually survive a restart. When false the
  /// prompt warns, rather than letting the user believe it was stored.
  final bool vaultIsPersistent;

  /// Whether to offer saving the password. Requires both a persistent store and
  /// a credential record to save it against, so it is false for a connection
  /// that asks every time with nowhere to put the answer.
  final bool canRemember;

  @override
  State<CredentialPrompt> createState() => _CredentialPromptState();
}

class _CredentialPromptState extends State<CredentialPrompt> {
  late final TextEditingController _username = TextEditingController(
    text: widget.initialUsername,
  );
  final TextEditingController _password = TextEditingController();

  bool _obscure = true;

  /// Defaults to on: someone who takes the trouble to save a credential and
  /// then has to type the password again anyway would rightly call it broken.
  bool _remember = true;

  String? _usernameError;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _username.text.trim();
    if (username.isEmpty) {
      setState(
        () => _usernameError = AppLocalizations.of(
          context,
        ).validationUsernameRequired,
      );
      return;
    }
    final (parsedUsername, domain) = splitDomain(username);
    Navigator.of(context).pop((
      username: parsedUsername,
      password: _password.text,
      domain: domain,
      remember: widget.canRemember && _remember,
    ));
  }

  /// `DOMAIN\user` names a domain; `user@domain` carries it in the user name
  /// itself and is passed through untouched.
  static (String, String) splitDomain(String raw) {
    final backslash = raw.indexOf(r'\');
    if (backslash > 0) {
      return (raw.substring(backslash + 1), raw.substring(0, backslash));
    }
    return (raw, '');
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);

    return AlertDialog(
      backgroundColor: colors.solidBackgroundFillColorTertiary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        widget.title,
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
            if (widget.message != null) ...[
              Text(
                widget.message!,
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: colors.textFillColorSecondary,
                ),
              ),
              const SizedBox(height: 16),
            ],
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
                        onSubmitted: (_) => _submit(),
                        autofocus: true,
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              kFluentControlRadius,
                            ),
                            borderSide: BorderSide(
                              color: colors.accentFillColorDefault,
                              width: 2,
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
            if (widget.canRemember) ...[
              const SizedBox(height: 16),
              FluentCheckbox(
                label: AppLocalizations.of(context).rememberPassword,
                description: AppLocalizations.of(context).rememberPasswordBody,
                value: _remember,
                onChanged: (value) => setState(() => _remember = value),
              ),
            ],
            if (!widget.vaultIsPersistent) ...[
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
                      AppLocalizations.of(context).passwordOnlyThisSession,
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
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: colors.accentFillColorDefault,
            foregroundColor: colors.textOnAccentFillColorPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Text(AppLocalizations.of(context).connect),
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
