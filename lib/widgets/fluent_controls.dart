/// Reusable WinUI-shaped form controls.
///
/// Material's defaults are the wrong shape for this app: Fluent form controls
/// are 32px tall, 4px radius, use `ControlFillColorDefault` at rest and shift
/// through `ControlFillColorSecondary`/`Tertiary` on hover and press. These wrap
/// the Material widgets so every form in the app shares that geometry instead of
/// re-deriving it.
library;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../theme/fluent_colors.dart';

/// Standard Fluent control height for buttons, inputs and pickers.
const double kFluentControlHeight = 32;

/// Corner radius for in-page controls. Top-level surfaces use 8.
const double kFluentControlRadius = 4;

/// A settings group rendered as a Fluent card.
class FluentSettingsCard extends StatelessWidget {
  const FluentSettingsCard({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w600,
                color: colors.textFillColorPrimary,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: colors.cardBackgroundFillColorDefault,
            border: Border.all(color: colors.cardStrokeColorDefault),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A label/control row. The label column is fixed so controls line up down the
/// form rather than stepping in and out with the length of each label.
class FluentField extends StatelessWidget {
  const FluentField({
    super.key,
    required this.label,
    required this.child,
    this.description,
  });

  final String label;
  final Widget child;

  /// Shown under the control; used for the "why" behind a setting.
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: colors.textFillColorPrimary,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              if (description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    description!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: colors.textFillColorTertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single-line text input.
class FluentTextField extends StatefulWidget {
  const FluentTextField({
    super.key,
    required this.controller,
    this.placeholder,
    this.onChanged,
    this.errorText,
    this.enabled = true,
    this.maxWidth,
  });

  final TextEditingController controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool enabled;
  final double? maxWidth;

  @override
  State<FluentTextField> createState() => _FluentTextFieldState();
}

class _FluentTextFieldState extends State<FluentTextField> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final hasError = widget.errorText != null;

    final field = SizedBox(
      height: kFluentControlHeight,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          style: TextStyle(fontSize: 14, color: colors.textFillColorPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.placeholder,
            hintStyle: TextStyle(
              fontSize: 14,
              color: colors.textFillColorTertiary,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            filled: true,
            fillColor: widget.enabled
                ? colors.controlFillColorDefault
                : colors.controlFillColorDisabled,
            border: _border(colors, hasError),
            enabledBorder: _border(colors, hasError),
            focusedBorder: _border(colors, hasError, focused: true),
            disabledBorder: _border(colors, hasError),
          ),
        ),
      ),
    );

    final sized = widget.maxWidth == null
        ? field
        : Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: widget.maxWidth, child: field),
          );

    if (!hasError) {
      return sized;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sized,
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            widget.errorText!,
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              color: colors.systemFillColorCritical,
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(
    FluentColors colors,
    bool hasError, {
    bool focused = false,
  }) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(kFluentControlRadius),
    borderSide: BorderSide(
      color: hasError
          ? colors.systemFillColorCritical
          : focused
          ? colors.accentFillColorDefault
          : _hovered
          ? colors.controlStrokeColorSecondary
          : colors.controlStrokeColorDefault,
      width: focused ? 2 : 1,
    ),
  );
}

/// A dropdown shaped like the rest of the form.
class FluentDropdown<T> extends StatelessWidget {
  const FluentDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.maxWidth,
  });

  final T value;

  /// Label for each value, in display order.
  final List<(T, String)> items;

  final ValueChanged<T>? onChanged;
  final bool enabled;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final dropdown = SizedBox(
      height: kFluentControlHeight,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          onChanged: enabled && onChanged != null
              ? (next) => onChanged!(next as T)
              : null,
          style: TextStyle(fontSize: 14, color: colors.textFillColorPrimary),
          dropdownColor: colors.solidBackgroundFillColorTertiary,
          borderRadius: BorderRadius.circular(8),
          icon: Icon(
            FluentIcons.chevron_down_24_regular,
            size: 16,
            color: enabled
                ? colors.textFillColorSecondary
                : colors.textFillColorDisabled,
          ),
          items: [
            for (final (itemValue, label) in items)
              DropdownMenuItem<T>(
                value: itemValue,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: enabled
                        ? colors.textFillColorPrimary
                        : colors.textFillColorDisabled,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final boxed = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: enabled
            ? colors.controlFillColorDefault
            : colors.controlFillColorDisabled,
        border: Border.all(color: colors.controlStrokeColorDefault),
        borderRadius: BorderRadius.circular(kFluentControlRadius),
      ),
      child: dropdown,
    );

    return maxWidth == null
        ? boxed
        : Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: maxWidth, child: boxed),
          );
  }
}

/// A labelled checkbox with the description underneath.
class FluentCheckbox extends StatelessWidget {
  const FluentCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? description;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    void toggle() {
      if (enabled && onChanged != null) {
        onChanged!(!value);
      }
    }

    return InkWell(
      onTap: enabled ? toggle : null,
      borderRadius: BorderRadius.circular(kFluentControlRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        // A Row hands its non-flexible children unbounded width, so a checkbox
        // dropped straight into one would give the Expanded below no room to
        // expand into and assert. Shrinking to the content in that case keeps
        // the control usable in both a form's column and a row of controls,
        // which is exactly the sort of thing a shared widget should absorb
        // rather than push onto every caller.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bounded = constraints.hasBoundedWidth;
            return Row(
              mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: value,
                    onChanged: enabled && onChanged != null
                        ? (next) => onChanged!(next ?? false)
                        : null,
                    activeColor: colors.accentFillColorDefault,
                    checkColor: colors.textOnAccentFillColorPrimary,
                    side: BorderSide(color: colors.controlStrokeColorSecondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kFluentControlRadius),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 12),
                _CheckboxLabel(
                  label: label,
                  description: description,
                  enabled: enabled,
                  colors: colors,
                  flex: bounded,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The label and description beside a [FluentCheckbox].
///
/// Split out so it can be [Expanded] when the incoming width is bounded and
/// [Flexible] when it is not; the two are not interchangeable.
class _CheckboxLabel extends StatelessWidget {
  const _CheckboxLabel({
    required this.label,
    required this.description,
    required this.enabled,
    required this.colors,
    required this.flex,
  });

  final String label;
  final String? description;
  final bool enabled;
  final FluentColors colors;
  final bool flex;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: enabled
                ? colors.textFillColorPrimary
                : colors.textFillColorDisabled,
          ),
        ),
        if (description != null)
          Text(
            description!,
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              color: colors.textFillColorTertiary,
            ),
          ),
      ],
    );
    return flex ? Expanded(child: column) : Flexible(child: column);
  }
}

/// A primary button, e.g. Save.
class FluentPrimaryButton extends StatelessWidget {
  const FluentPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return SizedBox(
      height: kFluentControlHeight,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.accentFillColorDefault,
          foregroundColor: colors.textOnAccentFillColorPrimary,
          disabledBackgroundColor: colors.controlFillColorDisabled,
          disabledForegroundColor: colors.textFillColorDisabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kFluentControlRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

/// A secondary button, e.g. Cancel.
class FluentSecondaryButton extends StatelessWidget {
  const FluentSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return SizedBox(
      height: kFluentControlHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textFillColorPrimary,
          backgroundColor: colors.controlFillColorDefault,
          side: BorderSide(color: colors.controlStrokeColorDefault),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kFluentControlRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
