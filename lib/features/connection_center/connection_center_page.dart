/// The connection centre: the app's home surface.
///
/// Layout follows the Windows App rather than the older Remote Desktop client:
/// a top tab strip instead of a navigation rail, a toolbar carrying search /
/// sort / refresh / view-mode, and a card grid where clicking anywhere on a card
/// starts the session.
///
/// The Apps tab is intentionally absent. It exists to list RemoteApps published
/// through a workspace feed, and without workspace support it could only ever be
/// empty — the app itself hides a tab that has no resources.
library;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../data/connection_store.dart';
import '../../data/credential_vault.dart';
import '../../data/storage_paths.dart';
import '../../models/pc_connection.dart';
import '../../theme/fluent_colors.dart';
import '../../widgets/pc_card.dart';
import '../pc_editor/pc_editor_page.dart';
import '../../l10n/generated/app_localizations.dart';

/// Top-level sections. Values are persisted, so the order matters.
enum ConnectionCenterTab { home, devices, favorites }

/// How the grid is ordered.
///
/// The labels live in the widget rather than on the enum: an enum entry is
/// constructed at compile time, where there is no BuildContext to resolve a
/// translation against. Enums carry identity; the UI carries the words for it.
enum ConnectionSort { recency, name, manual }

String _tabLabel(AppLocalizations l10n, ConnectionCenterTab tab) =>
    switch (tab) {
      ConnectionCenterTab.home => l10n.tabHome,
      ConnectionCenterTab.devices => l10n.tabDevices,
      ConnectionCenterTab.favorites => l10n.tabFavorites,
    };

String _sortLabel(AppLocalizations l10n, ConnectionSort sort) => switch (sort) {
  ConnectionSort.recency => l10n.sortRecency,
  ConnectionSort.name => l10n.sortName,
  ConnectionSort.manual => l10n.sortManual,
};

class ConnectionCenterPage extends StatefulWidget {
  const ConnectionCenterPage({
    super.key,
    required this.store,
    required this.vault,
    this.onConnect,
    this.onOpenSettings,
    this.initialTab = ConnectionCenterTab.devices,
  });

  final ConnectionStore store;

  /// Forwarded to the PC editor, which writes passwords into it.
  final CredentialVault vault;

  /// Opens a session. Left null in tests, where no engine is available.
  final void Function(PcConnection connection)? onConnect;

  /// Opens the settings page. Left null in tests for the same reason.
  final VoidCallback? onOpenSettings;

  final ConnectionCenterTab initialTab;

  @override
  State<ConnectionCenterPage> createState() => _ConnectionCenterPageState();
}

class _ConnectionCenterPageState extends State<ConnectionCenterPage> {
  late ConnectionCenterTab _tab = widget.initialTab;
  ConnectionSort _sort = ConnectionSort.recency;
  bool _gridView = true;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// The PCs the current tab should show, filtered and ordered.
  List<PcConnection> get _visibleConnections {
    final query = _query.trim().toLowerCase();

    var items = switch (_tab) {
      // Home shows the pinned set, which is what the app's Home tab is for.
      ConnectionCenterTab.home => widget.store.favorites,
      ConnectionCenterTab.devices => widget.store.connections,
      ConnectionCenterTab.favorites => widget.store.favorites,
    };

    if (query.isNotEmpty) {
      items = items
          .where(
            (connection) =>
                connection.displayName.toLowerCase().contains(query) ||
                connection.hostname.toLowerCase().contains(query) ||
                connection.group.toLowerCase().contains(query),
          )
          .toList();
    }

    final sorted = [...items];
    switch (_sort) {
      case ConnectionSort.recency:
        sorted.sort((a, b) {
          final aTime = a.lastConnectedAt;
          final bTime = b.lastConnectedAt;
          // Never-connected PCs sort last but keep a stable relative order.
          if (aTime == null && bTime == null) {
            return a.displayName.compareTo(b.displayName);
          }
          if (aTime == null) {
            return 1;
          }
          if (bTime == null) {
            return -1;
          }
          return bTime.compareTo(aTime);
        });
      case ConnectionSort.name:
        sorted.sort((a, b) => a.displayName.compareTo(b.displayName));
      case ConnectionSort.manual:
        // Insertion order, i.e. the order the user added them in. Reordering by
        // drag is not implemented yet.
        break;
    }
    return sorted;
  }

  Future<void> _openEditor({PcConnection? existing}) async {
    final result = await Navigator.of(context).push<PcConnection>(
      MaterialPageRoute(
        builder: (context) => PcEditorPage(
          store: widget.store,
          vault: widget.vault,
          existing: existing,
        ),
      ),
    );
    if (result != null) {
      await widget.store.upsertConnection(result);
    }
  }

  Future<void> _confirmDelete(PcConnection connection) async {
    final colors = FluentColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.solidBackgroundFillColorTertiary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(AppLocalizations.of(context).deletePcTitle),
        content: Text(
          AppLocalizations.of(context).deletePcBody(connection.displayName),
        ),
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
    if (confirmed ?? false) {
      await widget.store.deleteConnection(connection.id);
    }
  }

  List<PcCardAction> _actionsFor(PcConnection connection) => [
    PcCardAction(
      label: AppLocalizations.of(context).edit,
      icon: FluentIcons.edit_24_regular,
      onSelected: () => _openEditor(existing: connection),
    ),
    PcCardAction(
      label: connection.favorite
          ? AppLocalizations.of(context).cardRemoveFromFavorites
          : AppLocalizations.of(context).cardAddToFavorites,
      icon: connection.favorite
          ? FluentIcons.star_off_24_regular
          : FluentIcons.star_24_regular,
      onSelected: () => widget.store.setFavorite(
        connection.id,
        favorite: !connection.favorite,
      ),
    ),
    PcCardAction(
      label: AppLocalizations.of(context).delete,
      icon: FluentIcons.delete_24_regular,
      destructive: true,
      onSelected: () => _confirmDelete(connection),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final connections = _visibleConnections;

    return Scaffold(
      backgroundColor: colors.solidBackgroundFillColorBase,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            tab: _tab,
            onOpenSettings: widget.onOpenSettings,
            counts: {
              ConnectionCenterTab.home: widget.store.favorites.length,
              ConnectionCenterTab.devices: widget.store.connections.length,
              ConnectionCenterTab.favorites: widget.store.favorites.length,
            },
            onTabSelected: (tab) => setState(() => _tab = tab),
            onAdd: () => _openEditor(),
          ),
          const Divider(height: 1),
          _Toolbar(
            searchController: _searchController,
            sort: _sort,
            gridView: _gridView,
            onQueryChanged: (value) => setState(() => _query = value),
            onSortChanged: (sort) => setState(() => _sort = sort),
            onToggleView: () => setState(() => _gridView = !_gridView),
          ),
          if (widget.store.loadError != null)
            _LoadErrorBanner(error: widget.store.loadError!),
          Expanded(
            child: connections.isEmpty
                ? _EmptyState(
                    hasAnyConnection: widget.store.connections.isNotEmpty,
                    query: _query,
                    onAdd: () => _openEditor(),
                  )
                : _gridView
                ? _CardGrid(
                    connections: connections,
                    paths: widget.store.paths,
                    actionsFor: _actionsFor,
                    onConnect: widget.onConnect,
                    onToggleFavorite: (connection) => widget.store.setFavorite(
                      connection.id,
                      favorite: !connection.favorite,
                    ),
                  )
                : _ConnectionList(
                    connections: connections,
                    onConnect: widget.onConnect,
                    onToggleFavorite: (connection) => widget.store.setFavorite(
                      connection.id,
                      favorite: !connection.favorite,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.tab,
    required this.counts,
    required this.onTabSelected,
    required this.onAdd,
    this.onOpenSettings,
  });

  final ConnectionCenterTab tab;
  final Map<ConnectionCenterTab, int> counts;
  final ValueChanged<ConnectionCenterTab> onTabSelected;
  final VoidCallback onAdd;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Container(
      color: colors.layerFillColorDefault,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          for (final candidate in ConnectionCenterTab.values)
            _Tab(
              label: _tabLabel(AppLocalizations.of(context), candidate),
              count: counts[candidate] ?? 0,
              selected: candidate == tab,
              onTap: () => onTabSelected(candidate),
            ),
          const Spacer(),
          if (onOpenSettings != null)
            IconButton(
              onPressed: onOpenSettings,
              icon: const Icon(FluentIcons.settings_24_regular, size: 20),
              tooltip: AppLocalizations.of(context).settings,
              color: colors.textFillColorPrimary,
            ),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(FluentIcons.add_24_regular, size: 20),
            tooltip: AppLocalizations.of(context).addPc,
            color: colors.textFillColorPrimary,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count > 0 ? '$label ($count)' : label,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? colors.textFillColorPrimary
                    : colors.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: 6),
            // Fluent marks the active tab with an accent rule rather than a
            // filled pill.
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: 3,
              width: selected ? 24 : 0,
              decoration: BoxDecoration(
                color: colors.accentFillColorDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.sort,
    required this.gridView,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onToggleView,
  });

  final TextEditingController searchController;
  final ConnectionSort sort;
  final bool gridView;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ConnectionSort> onSortChanged;
  final VoidCallback onToggleView;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          SizedBox(
            width: 280,
            height: 32,
            child: TextField(
              controller: searchController,
              onChanged: onQueryChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: AppLocalizations.of(context).search,
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: colors.textFillColorTertiary,
                ),
                prefixIcon: Icon(
                  FluentIcons.search_24_regular,
                  size: 16,
                  color: colors.textFillColorSecondary,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 34),
                filled: true,
                fillColor: colors.controlFillColorDefault,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(
                    color: colors.controlStrokeColorDefault,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(
                    color: colors.controlStrokeColorDefault,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<ConnectionSort>(
            tooltip: AppLocalizations.of(context).sortBy,
            onSelected: onSortChanged,
            itemBuilder: (context) => [
              for (final candidate in ConnectionSort.values)
                CheckedPopupMenuItem<ConnectionSort>(
                  value: candidate,
                  checked: candidate == sort,
                  height: 36,
                  child: Text(
                    _sortLabel(AppLocalizations.of(context), candidate),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
            ],
            child: _ToolbarButton(
              icon: FluentIcons.arrow_sort_24_regular,
              label: _sortLabel(AppLocalizations.of(context), sort),
              // The child handles the tap for a PopupMenuButton, so this button
              // is presentational only.
              onPressed: null,
            ),
          ),
          const Spacer(),
          _ToolbarButton(
            icon: gridView
                ? FluentIcons.list_24_regular
                : FluentIcons.grid_24_regular,
            tooltip: gridView
                ? AppLocalizations.of(context).switchToList
                : AppLocalizations.of(context).switchToGrid,
            onPressed: onToggleView,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    this.label,
    this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final content = Container(
      height: 32,
      padding: EdgeInsets.symmetric(horizontal: label == null ? 8 : 12),
      decoration: BoxDecoration(
        color: colors.controlFillColorDefault,
        border: Border.all(color: colors.controlStrokeColorDefault),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.textFillColorPrimary),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(
              label!,
              style: TextStyle(
                fontSize: 14,
                color: colors.textFillColorPrimary,
              ),
            ),
          ],
        ],
      ),
    );

    final tappable = onPressed == null
        ? content
        : InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(4),
            child: content,
          );

    return tooltip == null
        ? tappable
        : Tooltip(message: tooltip!, child: tappable);
  }
}

class _LoadErrorBanner extends StatelessWidget {
  const _LoadErrorBanner({required this.error});

  final ConnectionStoreError error;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cardBackgroundFillColorDefault,
        border: Border.all(color: colors.systemFillColorCritical),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.warning_24_regular,
            size: 16,
            color: colors.systemFillColorCritical,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              switch (error) {
                ConnectionStoreError.unreadable => AppLocalizations.of(
                  context,
                ).storeErrorUnreadable,
                ConnectionStoreError.malformed => AppLocalizations.of(
                  context,
                ).storeErrorMalformed,
                ConnectionStoreError.unsupportedVersion => AppLocalizations.of(
                  context,
                ).storeErrorUnsupportedVersion,
                ConnectionStoreError.writeFailed => AppLocalizations.of(
                  context,
                ).storeErrorWriteFailed,
              },
              style: TextStyle(
                fontSize: 14,
                color: colors.textFillColorPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.connections,
    required this.paths,
    required this.actionsFor,
    required this.onToggleFavorite,
    this.onConnect,
  });

  final List<PcConnection> connections;

  /// Where the session previews live. The path is derived rather than looked
  /// up: a card whose preview is missing falls back to its own artwork, so
  /// there is nothing to check for first.
  final StoragePaths paths;

  final List<PcCardAction> Function(PcConnection) actionsFor;
  final ValueChanged<PcConnection> onToggleFavorite;
  final void Function(PcConnection)? onConnect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      // maxCrossAxisExtent keeps cards between roughly 240 and 320 logical
      // pixels as the window grows, which is where the app's own cards sit.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemCount: connections.length,
      itemBuilder: (context, index) {
        final connection = connections[index];
        return PcCard(
          key: ValueKey(connection.id),
          connection: connection,
          thumbnailPath: paths.thumbnailFor(connection.id),
          actions: actionsFor(connection),
          onToggleFavorite: () => onToggleFavorite(connection),
          onConnect: () => onConnect?.call(connection),
        );
      },
    );
  }
}

class _ConnectionList extends StatelessWidget {
  const _ConnectionList({
    required this.connections,
    required this.onToggleFavorite,
    this.onConnect,
  });

  final List<PcConnection> connections;
  final ValueChanged<PcConnection> onToggleFavorite;
  final void Function(PcConnection)? onConnect;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: connections.length,
      itemBuilder: (context, index) {
        final connection = connections[index];
        return InkWell(
          onTap: () => onConnect?.call(connection),
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                Icon(
                  FluentIcons.desktop_24_regular,
                  size: 16,
                  color: colors.textFillColorSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    connection.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textFillColorPrimary,
                    ),
                  ),
                ),
                Text(
                  connection.effectiveHostname,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textFillColorTertiary,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => onToggleFavorite(connection),
                  icon: Icon(
                    connection.favorite
                        ? FluentIcons.star_24_filled
                        : FluentIcons.star_24_regular,
                    size: 16,
                  ),
                  color: connection.favorite
                      ? colors.accentFillColorDefault
                      : colors.textFillColorTertiary,
                  splashRadius: 16,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasAnyConnection,
    required this.query,
    required this.onAdd,
  });

  final bool hasAnyConnection;
  final String query;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);

    // A search that matches nothing is a different situation from having no
    // saved PCs at all, and offering "add a PC" then would be unhelpful.
    final (title, body, showAction) = query.isNotEmpty
        ? (
            AppLocalizations.of(context).emptySearchTitle,
            AppLocalizations.of(context).emptySearchBody(query),
            false,
          )
        : hasAnyConnection
        ? (
            AppLocalizations.of(context).emptyFavoritesTitle,
            AppLocalizations.of(context).emptyFavoritesBody,
            false,
          )
        : (
            AppLocalizations.of(context).emptyNoDevicesTitle,
            AppLocalizations.of(context).emptyNoDevicesBody,
            true,
          );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.desktop_24_regular,
            size: 48,
            color: colors.textFillColorTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              height: 28 / 20,
              fontWeight: FontWeight.w600,
              color: colors.textFillColorPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              color: colors.textFillColorSecondary,
            ),
          ),
          if (showAction) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 32,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(FluentIcons.add_24_regular, size: 16),
                label: Text(
                  AppLocalizations.of(context).addPc,
                  style: TextStyle(fontSize: 14),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accentFillColorDefault,
                  foregroundColor: colors.textOnAccentFillColorPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
