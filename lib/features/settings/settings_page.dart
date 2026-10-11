/// Application settings.
///
/// Split the way the Windows App splits its own settings: appearance and about
/// are app-wide, while everything to do with a particular PC lives in that PC's
/// editor rather than here.
///
/// The account and gateway sections are the reason this page exists at all: a
/// credential could be created but never removed, and a gateway could only be
/// created from inside a PC's editor, so before this neither could be managed.
library;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../../data/connection_store.dart';
import '../../data/credential_vault.dart';
import '../../data/preferences_store.dart';
import '../../engine/rdc_engine.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/credential.dart';
import '../../models/gateway.dart';
import '../../theme/fluent_colors.dart';
import '../../widgets/fluent_controls.dart';
import '../pc_editor/credential_dialog.dart';
import '../pc_editor/gateway_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.preferences,
    required this.vault,
    required this.engine,
  });

  final ConnectionStore store;
  final PreferencesStore preferences;
  final CredentialVault vault;
  final RdcEngine engine;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChanged);
    widget.preferences.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChanged);
    widget.preferences.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _addCredential() async {
    final created = await showDialog<Credential>(
      context: context,
      builder: (context) => CredentialDialog(vault: widget.vault),
    );
    if (created != null) {
      await widget.store.upsertCredential(created);
    }
  }

  Future<void> _editCredential(Credential credential) async {
    final updated = await showDialog<Credential>(
      context: context,
      builder: (context) =>
          CredentialDialog(vault: widget.vault, existing: credential),
    );
    if (updated != null) {
      await widget.store.upsertCredential(updated);
    }
  }

  Future<void> _deleteCredential(Credential credential) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.accountDeleteTitle,
      // The password lives in the system store, so removing the record here
      // alone would leave it behind; the vault is cleared as well, and the
      // wording says so.
      body: l10n.accountDeleteBody(
        credential.friendlyName.isEmpty
            ? credential.qualifiedUsername
            : credential.friendlyName,
      ),
    );
    if (confirmed) {
      await widget.vault.delete(credential.id);
      await widget.store.deleteCredential(credential.id);
    }
  }

  Future<void> _addGateway() async {
    final created = await showDialog<Gateway>(
      context: context,
      builder: (context) => GatewayDialog(store: widget.store),
    );
    if (created != null) {
      await widget.store.upsertGateway(created);
    }
  }

  Future<void> _editGateway(Gateway gateway) async {
    final updated = await showDialog<Gateway>(
      context: context,
      builder: (context) =>
          GatewayDialog(store: widget.store, existing: gateway),
    );
    if (updated != null) {
      await widget.store.upsertGateway(updated);
    }
  }

  Future<void> _deleteGateway(Gateway gateway) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.gatewayDeleteTitle,
      body: l10n.gatewayDeleteBody(gateway.displayName),
    );
    if (confirmed) {
      await widget.store.deleteGateway(gateway.id);
    }
  }

  Future<bool> _confirm({required String title, required String body}) async {
    final colors = FluentColors.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.solidBackgroundFillColorTertiary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(title),
        content: SizedBox(width: 400, child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: colors.systemFillColorCritical,
            ),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final credentials = widget.store.credentials;
    final gateways = widget.store.gateways;

    return Scaffold(
      backgroundColor: FluentColors.of(context).solidBackgroundFillColorBase,
      body: Column(
        children: [
          _SettingsHeader(
            title: l10n.settings,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _appearance(l10n),
                      const SizedBox(height: 16),
                      _userAccounts(l10n, credentials),
                      const SizedBox(height: 16),
                      _gateways(l10n, gateways),
                      const SizedBox(height: 16),
                      _about(l10n),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appearance(AppLocalizations l10n) => FluentSettingsCard(
    title: l10n.settingsAppearance,
    children: [
      FluentField(
        label: l10n.settingsThemeMode,
        child: FluentDropdown<ThemeMode>(
          value: widget.preferences.preferences.themeMode,
          maxWidth: 200,
          items: [
            (ThemeMode.system, l10n.settingsThemeSystem),
            (ThemeMode.light, l10n.settingsThemeLight),
            (ThemeMode.dark, l10n.settingsThemeDark),
          ],
          onChanged: (mode) => widget.preferences.setThemeMode(mode),
        ),
      ),
    ],
  );

  Widget _userAccounts(AppLocalizations l10n, List<Credential> credentials) =>
      FluentSettingsCard(
        title: l10n.settingsUserAccounts,
        children: [
          _SectionNote(text: l10n.settingsUserAccountsBody),
          if (credentials.isEmpty)
            _EmptyNote(text: l10n.settingsAccountsEmpty)
          else
            for (final credential in credentials)
              _ManagedRow(
                key: ValueKey(credential.id),
                icon: FluentIcons.person_24_regular,
                title: credential.friendlyName.isEmpty
                    ? credential.qualifiedUsername
                    : credential.friendlyName,
                subtitle: credential.qualifiedUsername,
                onEdit: () => _editCredential(credential),
                onDelete: () => _deleteCredential(credential),
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: FluentSecondaryButton(
              label: l10n.newCredential,
              onPressed: _addCredential,
            ),
          ),
        ],
      );

  Widget _gateways(AppLocalizations l10n, List<Gateway> gateways) =>
      FluentSettingsCard(
        title: l10n.settingsGateways,
        children: [
          _SectionNote(text: l10n.settingsGatewaysBody),
          if (gateways.isEmpty)
            _EmptyNote(text: l10n.settingsGatewaysEmpty)
          else
            for (final gateway in gateways)
              _ManagedRow(
                key: ValueKey(gateway.id),
                icon: FluentIcons.cloud_24_regular,
                title: gateway.displayName,
                subtitle:
                    '${gateway.effectiveHostname}:${gateway.effectivePort}',
                onEdit: () => _editGateway(gateway),
                onDelete: () => _deleteGateway(gateway),
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: FluentSecondaryButton(
              label: l10n.newGateway,
              onPressed: _addGateway,
            ),
          ),
        ],
      );

  Widget _about(AppLocalizations l10n) => FluentSettingsCard(
    title: l10n.settingsAbout,
    children: [
      _InfoRow(label: l10n.aboutVersion, value: kAppVersion),
      _InfoRow(
        label: l10n.aboutEngine,
        value: widget.engine.isAvailable
            ? widget.engine.backendName
            : l10n.aboutEngineUnavailable,
      ),
    ],
  );
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: colors.layerFillColorDefault,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(FluentIcons.arrow_left_24_regular, size: 20),
            tooltip: AppLocalizations.of(context).back,
            color: colors.textFillColorPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              height: 28 / 20,
              fontWeight: FontWeight.w600,
              color: colors.textFillColorPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionNote extends StatelessWidget {
  const _SectionNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 16 / 12,
          color: FluentColors.of(context).textFillColorTertiary,
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          color: FluentColors.of(context).textFillColorSecondary,
        ),
      ),
    );
  }
}

/// A saved record with edit and delete affordances.
class _ManagedRow extends StatelessWidget {
  const _ManagedRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.textFillColorSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textFillColorPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textFillColorTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(FluentIcons.edit_24_regular, size: 16),
            tooltip: l10n.edit,
            color: colors.textFillColorSecondary,
            splashRadius: 16,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(FluentIcons.delete_24_regular, size: 16),
            tooltip: l10n.delete,
            color: colors.systemFillColorCritical,
            splashRadius: 16,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: colors.textFillColorSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: colors.textFillColorPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
