/// A saved-PC card for the connection centre grid.
///
/// Geometry follows the Fluent card recipe: 8px corner radius, a 1px
/// `CardStrokeColorDefault` contour, and elevation 8 of shadow. Following the
/// Windows App, the whole card is the connect affordance — there is no separate
/// Connect button — so the hover and focus treatments have to make that obvious.
library;

import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../models/pc_connection.dart';
import '../theme/fluent_colors.dart';
import '../../l10n/generated/app_localizations.dart';

/// One entry in the card's overflow menu.
class PcCardAction {
  const PcCardAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  /// Destructive actions are tinted with the critical colour, as WinUI does.
  final bool destructive;
}

class PcCard extends StatefulWidget {
  const PcCard({
    super.key,
    required this.connection,
    required this.onConnect,
    this.actions = const [],
    this.onToggleFavorite,
    this.thumbnailPath,
  });

  final PcConnection connection;

  /// Invoked by a click anywhere on the card.
  final VoidCallback onConnect;

  final List<PcCardAction> actions;

  /// When provided, a star button appears that pins the PC to Favorites.
  final VoidCallback? onToggleFavorite;

  /// Last session preview, if one has been captured. Plain remote PCs have no
  /// wallpaper to show, so the artwork falls back to a monitor illustration.
  final String? thumbnailPath;

  @override
  State<PcCard> createState() => _PcCardState();
}

class _PcCardState extends State<PcCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final connection = widget.connection;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onConnect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            // WinUI controls shift their fill on hover and again on press; the
            // card follows the same three-step progression.
            color: _pressed
                ? colors.controlFillColorTertiary
                : _hovered
                ? colors.controlFillColorSecondary
                : colors.cardBackgroundFillColorDefault,
            border: Border.all(
              color: _hovered
                  ? colors.controlStrokeColorSecondary
                  : colors.cardStrokeColorDefault,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.18 : 0.10),
                blurRadius: _hovered ? 16 : 8,
                offset: Offset(0, _hovered ? 4 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Thumbnail(
                  connection: connection,
                  path: widget.thumbnailPath,
                ),
              ),
              _Caption(
                connection: connection,
                hovered: _hovered,
                actions: widget.actions,
                onToggleFavorite: widget.onToggleFavorite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.connection, this.path});

  final PcConnection connection;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final hasPreview = path != null;

    return ClipRRect(
      // Only the top corners follow the card's radius; the caption sits flush
      // below, so rounding the bottom would leave a visible seam.
      borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
      child: Container(
        color: colors.solidBackgroundFillColorSecondary,
        alignment: Alignment.center,
        child: hasPreview
            ? Image.file(
                File(path!),
                fit: BoxFit.cover,
                // A stale or unreadable thumbnail must not take the grid down;
                // the generic artwork is a fine substitute.
                errorBuilder: (context, error, stack) =>
                    const _MonitorArtwork(),
              )
            : const _MonitorArtwork(),
      ),
    );
  }
}

/// Stands in for the generic monitor artwork the app shows for a plain PC.
class _MonitorArtwork extends StatelessWidget {
  const _MonitorArtwork();

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          FluentIcons.desktop_24_regular,
          size: 48,
          color: colors.textFillColorTertiary,
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context).cardRemoteDesktop,
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            color: colors.textFillColorTertiary,
          ),
        ),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({
    required this.connection,
    required this.hovered,
    required this.actions,
    this.onToggleFavorite,
  });

  final PcConnection connection;
  final bool hovered;
  final List<PcCardAction> actions;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  connection.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textFillColorPrimary,
                  ),
                ),
                // The host only earns a second line when it is not already the
                // title; otherwise the caption would just repeat itself.
                if (connection.friendlyName.isNotEmpty)
                  Text(
                    connection.effectiveHostname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: colors.textFillColorSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (onToggleFavorite != null)
            _IconAffordance(
              icon: connection.favorite
                  ? FluentIcons.star_24_filled
                  : FluentIcons.star_24_regular,
              tooltip: connection.favorite
                  ? AppLocalizations.of(context).cardRemoveFromFavorites
                  : AppLocalizations.of(context).cardAddToFavorites,
              // The star stays visible when pinned so Favorites membership is
              // legible at a glance, and fades in on hover otherwise.
              visible: connection.favorite || hovered,
              color: connection.favorite ? colors.accentFillColorDefault : null,
              onPressed: onToggleFavorite!,
            ),
          if (actions.isNotEmpty)
            _OverflowMenu(actions: actions, visible: hovered),
        ],
      ),
    );
  }
}

class _IconAffordance extends StatelessWidget {
  const _IconAffordance({
    required this.icon,
    required this.tooltip,
    required this.visible,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final bool visible;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 100),
      child: IgnorePointer(
        ignoring: !visible,
        child: Tooltip(
          message: tooltip,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            color: color ?? colors.textFillColorSecondary,
            splashRadius: 16,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.actions, required this.visible});

  final List<PcCardAction> actions;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 100),
      child: IgnorePointer(
        ignoring: !visible,
        child: PopupMenuButton<int>(
          tooltip: AppLocalizations.of(context).moreOptions,
          icon: Icon(
            FluentIcons.more_horizontal_24_regular,
            size: 16,
            color: colors.textFillColorSecondary,
          ),
          splashRadius: 16,
          padding: EdgeInsets.zero,
          iconSize: 16,
          onSelected: (index) => actions[index].onSelected(),
          itemBuilder: (context) => [
            for (var i = 0; i < actions.length; i++)
              PopupMenuItem<int>(
                value: i,
                height: 36,
                child: Row(
                  children: [
                    Icon(
                      actions[i].icon,
                      size: 16,
                      color: actions[i].destructive
                          ? colors.systemFillColorCritical
                          : colors.textFillColorPrimary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      actions[i].label,
                      style: TextStyle(
                        fontSize: 14,
                        color: actions[i].destructive
                            ? colors.systemFillColorCritical
                            : colors.textFillColorPrimary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
