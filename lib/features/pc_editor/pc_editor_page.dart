/// Add / edit a remote PC.
///
/// The form is split across the same four tabs the Windows App family uses —
/// General, Display, Devices & Audio, Folders — rather than one long page,
/// because the redirection options alone would bury the two fields that matter
/// (PC name and credentials) for anyone adding a PC for the first time.
library;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../data/connection_store.dart';
import '../../data/credential_vault.dart';
import '../../data/ids.dart';
import '../../models/credential.dart';
import '../../models/gateway.dart';
import '../../models/pc_connection.dart';
import '../../theme/fluent_colors.dart';
import '../../widgets/fluent_controls.dart';
import 'credential_dialog.dart';
import 'gateway_dialog.dart';
import '../../l10n/generated/app_localizations.dart';

class PcEditorPage extends StatefulWidget {
  const PcEditorPage({
    super.key,
    required this.store,
    required this.vault,
    this.existing,
  });

  final ConnectionStore store;

  /// Passed through to the credential dialog, which writes passwords into it.
  final CredentialVault vault;

  /// When non-null the form edits this connection; otherwise it creates one.
  final PcConnection? existing;

  @override
  State<PcEditorPage> createState() => _PcEditorPageState();
}

class _PcEditorPageState extends State<PcEditorPage> {
  static const double _portFieldWidth = 120;

  late final TextEditingController _hostname;
  late final TextEditingController _friendlyName;
  late final TextEditingController _group;
  late final TextEditingController _port;

  late CredentialMode _credentialMode;
  String? _credentialId;
  String? _gatewayId;

  late bool _reconnectIfDropped;
  late bool _adminSession;
  late bool _swapMouseButtons;

  late PcDisplaySettings _display;
  late PcRedirectionSettings _redirection;

  String? _hostnameError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _hostname = TextEditingController(text: existing?.hostname ?? '');
    _friendlyName = TextEditingController(text: existing?.friendlyName ?? '');
    _group = TextEditingController(text: existing?.group ?? '');
    _port = TextEditingController(
      text: '${existing?.port ?? PcConnection.defaultPort}',
    );

    _credentialMode = existing?.credentialMode ?? CredentialMode.askEveryTime;
    _credentialId = existing?.credentialId;
    _gatewayId = existing?.gatewayId;

    _reconnectIfDropped = existing?.reconnectIfDropped ?? true;
    _adminSession = existing?.adminSession ?? false;
    _swapMouseButtons = existing?.swapMouseButtons ?? false;

    _display = existing?.display ?? const PcDisplaySettings();
    _redirection = existing?.redirection ?? const PcRedirectionSettings();
  }

  @override
  void dispose() {
    _hostname.dispose();
    _friendlyName.dispose();
    _group.dispose();
    _port.dispose();
    super.dispose();
  }

  void _save() {
    final hostname = _hostname.text.trim();
    if (hostname.isEmpty) {
      setState(
        () => _hostnameError = AppLocalizations.of(
          context,
        ).validationPcNameRequired,
      );
      return;
    }
    setState(() => _hostnameError = null);

    final existing = widget.existing;
    final connection = PcConnection(
      id: existing?.id ?? newId(),
      hostname: hostname,
      friendlyName: _friendlyName.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? PcConnection.defaultPort,
      group: _group.text.trim(),
      credentialMode: _credentialMode,
      credentialId: _credentialId,
      gatewayId: _gatewayId,
      reconnectIfDropped: _reconnectIfDropped,
      adminSession: _adminSession,
      swapMouseButtons: _swapMouseButtons,
      display: _display,
      // Drop folder rows left blank. Adding a row is how the user starts one,
      // so blank rows are a normal intermediate state rather than an error, and
      // saving them would hand the session a share with no path.
      redirection: _redirection.copyWith(
        folders: _redirection.folders
            .where((folder) => folder.path.trim().isNotEmpty)
            .toList(),
      ),
      favorite: existing?.favorite ?? false,
      lastConnectedAt: existing?.lastConnectedAt,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    Navigator.of(context).pop(connection);
  }

  Future<void> _addGateway() async {
    final created = await showDialog<Gateway>(
      context: context,
      builder: (context) => GatewayDialog(store: widget.store),
    );
    if (created == null) {
      return;
    }
    await widget.store.upsertGateway(created);
    setState(() => _gatewayId = created.id);
  }

  Future<void> _editGateway() async {
    final existing = widget.store.gatewayById(_gatewayId!);
    if (existing == null) {
      return;
    }
    final updated = await showDialog<Gateway>(
      context: context,
      builder: (context) =>
          GatewayDialog(store: widget.store, existing: existing),
    );
    if (updated != null) {
      await widget.store.upsertGateway(updated);
    }
  }

  Future<void> _addCredential() async {
    final created = await showDialog<Credential>(
      context: context,
      builder: (context) => CredentialDialog(vault: widget.vault),
    );
    if (created == null) {
      return;
    }
    // Persist immediately so the picker can reference it; the password itself
    // goes to the platform vault inside the dialog.
    await widget.store.upsertCredential(created);
    setState(() {
      _credentialMode = CredentialMode.saved;
      _credentialId = created.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: colors.solidBackgroundFillColorBase,
        body: Column(
          children: [
            _EditorHeader(
              title: _isEditing
                  ? AppLocalizations.of(context).editorEditPcTitle
                  : AppLocalizations.of(context).addPc,
              onBack: () => Navigator.of(context).pop(),
            ),
            Container(
              color: colors.layerFillColorDefault,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: colors.accentFillColorDefault,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: colors.dividerStrokeColorDefault,
                labelColor: colors.textFillColorPrimary,
                unselectedLabelColor: colors.textFillColorSecondary,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 14),
                tabs: [
                  Tab(
                    text: AppLocalizations.of(context).tabGeneral,
                    height: 40,
                  ),
                  Tab(
                    text: AppLocalizations.of(context).tabDisplay,
                    height: 40,
                  ),
                  Tab(
                    text: AppLocalizations.of(context).tabDevicesAndAudio,
                    height: 40,
                  ),
                  Tab(
                    text: AppLocalizations.of(context).tabFolders,
                    height: 40,
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _generalTab(),
                  _displayTab(),
                  _devicesTab(),
                  _foldersTab(),
                ],
              ),
            ),
            _EditorFooter(
              onCancel: () => Navigator.of(context).pop(),
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }

  // --- General -------------------------------------------------------------

  Widget _generalTab() {
    final credentials = widget.store.credentials;
    final gateways = widget.store.gateways;

    return _TabScroller(
      children: [
        FluentSettingsCard(
          children: [
            FluentField(
              label: AppLocalizations.of(context).fieldPcName,
              child: FluentTextField(
                controller: _hostname,
                placeholder: AppLocalizations.of(
                  context,
                ).fieldPcNamePlaceholder,
                errorText: _hostnameError,
                onChanged: (_) {
                  if (_hostnameError != null) {
                    setState(() => _hostnameError = null);
                  }
                },
              ),
            ),
            FluentField(
              label: AppLocalizations.of(context).fieldPort,
              child: FluentTextField(
                controller: _port,
                placeholder: '${PcConnection.defaultPort}',
                maxWidth: _portFieldWidth,
              ),
            ),
            FluentField(
              label: AppLocalizations.of(context).fieldFriendlyName,
              child: FluentTextField(
                controller: _friendlyName,
                placeholder: AppLocalizations.of(
                  context,
                ).fieldFriendlyNamePlaceholder,
              ),
            ),
            FluentField(
              label: AppLocalizations.of(context).fieldGroup,
              child: FluentTextField(
                controller: _group,
                placeholder: AppLocalizations.of(context).optional,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FluentSettingsCard(
          title: AppLocalizations.of(context).credentials,
          children: [
            FluentField(
              label: AppLocalizations.of(context).fieldUserAccount,
              child: Row(
                children: [
                  Expanded(
                    child: FluentDropdown<String>(
                      value: _credentialMode == CredentialMode.askEveryTime
                          ? _askEveryTimeValue
                          : (_credentialId ?? _askEveryTimeValue),
                      items: [
                        (
                          _askEveryTimeValue,
                          AppLocalizations.of(context).askEveryTime,
                        ),
                        for (final credential in credentials)
                          (
                            credential.id,
                            credential.friendlyName.isEmpty
                                ? credential.qualifiedUsername
                                : credential.friendlyName,
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        if (value == _askEveryTimeValue) {
                          _credentialMode = CredentialMode.askEveryTime;
                          _credentialId = null;
                        } else {
                          _credentialMode = CredentialMode.saved;
                          _credentialId = value;
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FluentSecondaryButton(
                    label: AppLocalizations.of(context).newCredential,
                    onPressed: _addCredential,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FluentSettingsCard(
          title: AppLocalizations.of(context).gateway,
          children: [
            FluentField(
              label: AppLocalizations.of(context).gateway,
              child: Row(
                children: [
                  Expanded(
                    child: FluentDropdown<String>(
                      value: _gatewayId ?? _noGatewayValue,
                      items: [
                        // An empty list would leave the picker with nothing but
                        // "not configured" and no way to change that, which is
                        // what the create button beside it is for.
                        (
                          _noGatewayValue,
                          gateways.isEmpty
                              ? AppLocalizations.of(context).notConfigured
                              : AppLocalizations.of(context).notConfigured,
                        ),
                        for (final gateway in gateways)
                          (gateway.id, gateway.displayName),
                      ],
                      onChanged: (value) => setState(
                        () => _gatewayId = value == _noGatewayValue
                            ? null
                            : value,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FluentSecondaryButton(
                    label: AppLocalizations.of(context).newGateway,
                    onPressed: _addGateway,
                  ),
                  if (_gatewayId != null) ...[
                    const SizedBox(width: 8),
                    FluentSecondaryButton(
                      label: AppLocalizations.of(context).edit,
                      onPressed: _editGateway,
                    ),
                  ],
                ],
              ),
            ),
            // Bypass-for-local-addresses lives on the gateway rather than here,
            // because it is a property of the gateway: the same gateway is used
            // by several connections and the answer should not differ between
            // them. It is edited in the gateway dialog.
          ],
        ),
        const SizedBox(height: 16),
        FluentSettingsCard(
          title: AppLocalizations.of(context).session,
          children: [
            FluentCheckbox(
              label: AppLocalizations.of(context).fieldReconnect,
              value: _reconnectIfDropped,
              onChanged: (value) => setState(() => _reconnectIfDropped = value),
            ),
            FluentCheckbox(
              label: AppLocalizations.of(context).fieldAdminSession,
              description: AppLocalizations.of(context).fieldAdminSessionBody,
              value: _adminSession,
              onChanged: (value) => setState(() => _adminSession = value),
            ),
            FluentCheckbox(
              label: AppLocalizations.of(context).fieldSwapMouseButtons,
              value: _swapMouseButtons,
              onChanged: (value) => setState(() => _swapMouseButtons = value),
            ),
          ],
        ),
      ],
    );
  }

  // --- Display -------------------------------------------------------------

  Widget _displayTab() {
    // The current resolution may not be one of the presets (it could have been
    // set by an earlier build or by dynamic resize), so include it rather than
    // letting the dropdown assert on an unknown value.
    final presets = <Resolution>[
      ...Resolution.presets,
      if (!Resolution.presets.contains(_display.resolution))
        _display.resolution,
    ];

    return _TabScroller(
      children: [
        FluentSettingsCard(
          children: [
            FluentField(
              label: AppLocalizations.of(context).fieldResolution,
              child: FluentDropdown<Resolution>(
                value: _display.resolution,
                enabled: !_display.updateResolutionOnResize,
                items: [for (final preset in presets) (preset, preset.label)],
                onChanged: (value) => setState(
                  () => _display = _display.copyWith(resolution: value),
                ),
              ),
            ),
            // Display configuration (all / single / selected monitors) is
            // deliberately absent. Spanning several monitors needs either one
            // window per monitor or a window stretched across them, and this
            // client draws the session into a single window -- so asking the
            // host for a spanned desktop would produce a very wide picture
            // squeezed into a normal window, which is worse than not offering
            // the choice. The native side already understands the setting; it
            // is waiting on the windowing work, not on anything here.
            FluentField(
              label: AppLocalizations.of(context).fieldColorQuality,
              child: FluentDropdown<int>(
                value: _display.colorDepth,
                maxWidth: 200,
                items: [
                  (32, AppLocalizations.of(context).colorQualityHighest),
                  (24, AppLocalizations.of(context).colorQualityEnhanced),
                  (16, AppLocalizations.of(context).colorQualityHigh),
                ],
                onChanged: (value) => setState(
                  () => _display = _display.copyWith(colorDepth: value),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FluentSettingsCard(
          title: AppLocalizations.of(context).displayWindowBehaviour,
          children: [
            FluentCheckbox(
              label: AppLocalizations.of(context).fieldStartFullScreen,
              value: _display.startFullScreen,
              onChanged: (value) => setState(
                () => _display = _display.copyWith(startFullScreen: value),
              ),
            ),
            FluentCheckbox(
              label: AppLocalizations.of(context).fieldFitToWindow,
              description: AppLocalizations.of(context).fieldFitToWindowBody,
              value: _display.fitSessionToWindow,
              onChanged: (value) => setState(
                () => _display = _display.copyWith(fitSessionToWindow: value),
              ),
            ),
            FluentCheckbox(
              label: AppLocalizations.of(context).fieldUpdateResolutionOnResize,
              description: AppLocalizations.of(
                context,
              ).fieldUpdateResolutionOnResizeBody,
              value: _display.updateResolutionOnResize,
              onChanged: (value) => setState(
                () => _display = _display.copyWith(
                  updateResolutionOnResize: value,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Devices & audio -----------------------------------------------------

  Widget _devicesTab() {
    return _TabScroller(
      children: [
        FluentSettingsCard(
          title: AppLocalizations.of(context).clipboard,
          children: [
            FluentField(
              label: AppLocalizations.of(context).fieldClipboardRedirection,
              child: FluentDropdown<ClipboardMode>(
                value: _redirection.clipboardMode,
                items: [
                  (
                    ClipboardMode.bidirectional,
                    AppLocalizations.of(context).clipboardBidirectional,
                  ),
                  (
                    ClipboardMode.localToRemote,
                    AppLocalizations.of(context).clipboardLocalToRemote,
                  ),
                  (
                    ClipboardMode.remoteToLocal,
                    AppLocalizations.of(context).clipboardRemoteToLocal,
                  ),
                  (
                    ClipboardMode.disabled,
                    AppLocalizations.of(context).clipboardDisabled,
                  ),
                ],
                onChanged: (value) => setState(
                  () => _redirection = _redirection.copyWith(
                    clipboardMode: value,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FluentSettingsCard(
          title: AppLocalizations.of(context).audio,
          children: [
            FluentField(
              label: AppLocalizations.of(context).fieldAudioPlayback,
              child: FluentDropdown<AudioPlaybackMode>(
                value: _redirection.audioPlayback,
                items: [
                  (
                    AudioPlaybackMode.onThisComputer,
                    AppLocalizations.of(context).audioOnThisComputer,
                  ),
                  (
                    AudioPlaybackMode.onRemotePc,
                    AppLocalizations.of(context).audioOnRemotePc,
                  ),
                  (
                    AudioPlaybackMode.never,
                    AppLocalizations.of(context).audioNever,
                  ),
                ],
                onChanged: (value) => setState(
                  () => _redirection = _redirection.copyWith(
                    audioPlayback: value,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FluentSettingsCard(
          title: AppLocalizations.of(context).tabDevices,
          children: [
            FluentCheckbox(
              label: AppLocalizations.of(context).fieldRedirectDrives,
              value: _redirection.redirectDrives,
              onChanged: (value) => setState(
                () =>
                    _redirection = _redirection.copyWith(redirectDrives: value),
              ),
            ),
            // Microphone, printer, smart card and camera are deliberately
            // absent rather than present and inert. Each needs a backend this
            // client does not have -- an audio capture device, a print-job
            // handler, PCSC, a camera pipeline -- and advertising a capability
            // that never produces anything is worse than not offering it: the
            // remote machine shows a device that silently does nothing.
            // 麦克风、打印机、智能卡、摄像头四个选项是有意移除的，而不是留着不生效。
          ],
        ),
      ],
    );
  }

  // --- Folders -------------------------------------------------------------

  Widget _foldersTab() {
    final colors = FluentColors.of(context);
    final folders = _redirection.folders;

    return _TabScroller(
      children: [
        FluentSettingsCard(
          title: AppLocalizations.of(context).redirectedFolders,
          children: [
            if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  AppLocalizations.of(context).foldersEmpty,
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: colors.textFillColorSecondary,
                  ),
                ),
              )
            else
              for (var index = 0; index < folders.length; index++)
                _FolderRow(
                  key: ValueKey('folder-$index'),
                  folder: folders[index],
                  onPathChanged: (path) => setState(() {
                    final updated = [...folders];
                    updated[index] = updated[index].copyWith(path: path);
                    _redirection = _redirection.copyWith(folders: updated);
                  }),
                  onReadOnlyChanged: (readOnly) => setState(() {
                    final updated = [...folders];
                    updated[index] = updated[index].copyWith(
                      readOnly: readOnly,
                    );
                    _redirection = _redirection.copyWith(folders: updated);
                  }),
                  onRemove: () => setState(() {
                    final updated = [...folders]..removeAt(index);
                    _redirection = _redirection.copyWith(folders: updated);
                  }),
                ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FluentSecondaryButton(
                label: AppLocalizations.of(context).addFolder,
                onPressed: () => setState(() {
                  // Added empty rather than pre-filled with a guess: the path is
                  // the whole content of the row, and a placeholder like D:\
                  // would be saved as-is by anyone who did not notice it. Saving
                  // drops rows that were left blank.
                  _redirection = _redirection.copyWith(
                    folders: [
                      ...folders,
                      const RedirectedFolder(path: ''),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const String _askEveryTimeValue = '\u0000ask';
  static const String _noGatewayValue = '\u0000none';
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.title, required this.onBack});

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

class _EditorFooter extends StatelessWidget {
  const _EditorFooter({required this.onCancel, required this.onSave});

  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: colors.layerFillColorDefault,
        border: Border(
          top: BorderSide(color: colors.dividerStrokeColorDefault),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FluentSecondaryButton(
            label: AppLocalizations.of(context).cancel,
            onPressed: onCancel,
          ),
          const SizedBox(width: 8),
          FluentPrimaryButton(
            label: AppLocalizations.of(context).save,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

class _TabScroller extends StatelessWidget {
  const _TabScroller({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _FolderRow extends StatefulWidget {
  const _FolderRow({
    super.key,
    required this.folder,
    required this.onPathChanged,
    required this.onReadOnlyChanged,
    required this.onRemove,
  });

  final RedirectedFolder folder;
  final ValueChanged<String> onPathChanged;
  final ValueChanged<bool> onReadOnlyChanged;
  final VoidCallback onRemove;

  @override
  State<_FolderRow> createState() => _FolderRowState();
}

class _FolderRowState extends State<_FolderRow> {
  late final TextEditingController _path = TextEditingController(
    text: widget.folder.path,
  );

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final folder = widget.folder;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            FluentIcons.folder_24_regular,
            size: 16,
            color: colors.textFillColorSecondary,
          ),
          const SizedBox(width: 12),
          // Editable: the path is the entire content of the row, so a row that
          // cannot be given one is not a feature at all. A native folder picker
          // would be nicer and is worth doing later.
          Expanded(
            child: FluentTextField(
              controller: _path,
              placeholder: AppLocalizations.of(context).folderPathPlaceholder,
              onChanged: widget.onPathChanged,
            ),
          ),
          FluentCheckbox(
            label: AppLocalizations.of(context).folderReadOnly,
            value: folder.readOnly,
            onChanged: widget.onReadOnlyChanged,
          ),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(FluentIcons.dismiss_24_regular, size: 16),
            tooltip: AppLocalizations.of(context).remove,
            color: colors.textFillColorSecondary,
            splashRadius: 16,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
