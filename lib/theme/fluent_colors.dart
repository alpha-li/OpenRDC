/// The WinUI 3 colour tokens the Windows App is built from.
///
/// Values are the WinUI theme resources verbatim, including their alpha, which
/// is what makes the layered look work: several of these are translucent and
/// only read correctly once composited over the right backdrop. Do not
/// "simplify" them to opaque approximations.
///
/// Naming follows the WinUI resources so the two can be compared directly.
library;

import 'package:flutter/material.dart';

@immutable
class FluentColors extends ThemeExtension<FluentColors> {
  const FluentColors({
    required this.solidBackgroundFillColorBase,
    required this.solidBackgroundFillColorSecondary,
    required this.solidBackgroundFillColorTertiary,
    required this.solidBackgroundFillColorQuarternary,
    required this.layerFillColorDefault,
    required this.layerOnAcrylicFillColorDefault,
    required this.cardBackgroundFillColorDefault,
    required this.cardBackgroundFillColorSecondary,
    required this.cardStrokeColorDefault,
    required this.controlFillColorDefault,
    required this.controlFillColorSecondary,
    required this.controlFillColorTertiary,
    required this.controlFillColorDisabled,
    required this.controlStrokeColorDefault,
    required this.controlStrokeColorSecondary,
    required this.surfaceStrokeColorDefault,
    required this.dividerStrokeColorDefault,
    required this.textFillColorPrimary,
    required this.textFillColorSecondary,
    required this.textFillColorTertiary,
    required this.textFillColorDisabled,
    required this.textOnAccentFillColorPrimary,
    required this.accentFillColorDefault,
    required this.accentFillColorSecondary,
    required this.accentFillColorTertiary,
    required this.focusStrokeColorOuter,
    required this.focusStrokeColorInner,
    required this.smokeFillColorDefault,
    required this.systemFillColorSuccess,
    required this.systemFillColorCaution,
    required this.systemFillColorCritical,
    required this.systemFillColorNeutral,
  });

  // Surfaces ---------------------------------------------------------------
  final Color solidBackgroundFillColorBase;
  final Color solidBackgroundFillColorSecondary;
  final Color solidBackgroundFillColorTertiary;
  final Color solidBackgroundFillColorQuarternary;
  final Color layerFillColorDefault;
  final Color layerOnAcrylicFillColorDefault;

  // Cards ------------------------------------------------------------------
  final Color cardBackgroundFillColorDefault;
  final Color cardBackgroundFillColorSecondary;
  final Color cardStrokeColorDefault;

  // Controls ---------------------------------------------------------------
  final Color controlFillColorDefault;
  final Color controlFillColorSecondary;
  final Color controlFillColorTertiary;
  final Color controlFillColorDisabled;
  final Color controlStrokeColorDefault;
  final Color controlStrokeColorSecondary;

  // Strokes ----------------------------------------------------------------
  final Color surfaceStrokeColorDefault;
  final Color dividerStrokeColorDefault;

  // Text -------------------------------------------------------------------
  final Color textFillColorPrimary;
  final Color textFillColorSecondary;
  final Color textFillColorTertiary;
  final Color textFillColorDisabled;
  final Color textOnAccentFillColorPrimary;

  // Accent -----------------------------------------------------------------
  final Color accentFillColorDefault;
  final Color accentFillColorSecondary;
  final Color accentFillColorTertiary;

  // Focus and modality -----------------------------------------------------
  final Color focusStrokeColorOuter;
  final Color focusStrokeColorInner;
  final Color smokeFillColorDefault;

  // Status -----------------------------------------------------------------
  final Color systemFillColorSuccess;
  final Color systemFillColorCaution;
  final Color systemFillColorCritical;
  final Color systemFillColorNeutral;

  static const FluentColors light = FluentColors(
    solidBackgroundFillColorBase: Color(0xFFF3F3F3),
    solidBackgroundFillColorSecondary: Color(0xFFEEEEEE),
    solidBackgroundFillColorTertiary: Color(0xFFF9F9F9),
    solidBackgroundFillColorQuarternary: Color(0xFFFFFFFF),
    layerFillColorDefault: Color(0x80FFFFFF),
    layerOnAcrylicFillColorDefault: Color(0x40FFFFFF),
    cardBackgroundFillColorDefault: Color(0xB3FFFFFF),
    cardBackgroundFillColorSecondary: Color(0x80F6F6F6),
    cardStrokeColorDefault: Color(0x0F000000),
    controlFillColorDefault: Color(0xB3FFFFFF),
    controlFillColorSecondary: Color(0x80F9F9F9),
    controlFillColorTertiary: Color(0x4DF9F9F9),
    controlFillColorDisabled: Color(0x4DF9F9F9),
    controlStrokeColorDefault: Color(0x0F000000),
    controlStrokeColorSecondary: Color(0x29000000),
    surfaceStrokeColorDefault: Color(0x66757575),
    dividerStrokeColorDefault: Color(0x0F000000),
    textFillColorPrimary: Color(0xE4000000),
    textFillColorSecondary: Color(0x9E000000),
    textFillColorTertiary: Color(0x72000000),
    textFillColorDisabled: Color(0x5C000000),
    textOnAccentFillColorPrimary: Color(0xFFFFFFFF),
    accentFillColorDefault: Color(0xFF005FB8),
    accentFillColorSecondary: Color(0xE6005FB8),
    accentFillColorTertiary: Color(0xCC005FB8),
    focusStrokeColorOuter: Color(0xE4000000),
    focusStrokeColorInner: Color(0xB3FFFFFF),
    smokeFillColorDefault: Color(0x4D000000),
    systemFillColorSuccess: Color(0xFF0F7B0F),
    systemFillColorCaution: Color(0xFF9D5D00),
    systemFillColorCritical: Color(0xFFC42B1C),
    systemFillColorNeutral: Color(0xFF8A8A8A),
  );

  static const FluentColors dark = FluentColors(
    solidBackgroundFillColorBase: Color(0xFF202020),
    solidBackgroundFillColorSecondary: Color(0xFF1C1C1C),
    solidBackgroundFillColorTertiary: Color(0xFF282828),
    solidBackgroundFillColorQuarternary: Color(0xFF2C2C2C),
    layerFillColorDefault: Color(0x4C3A3A3A),
    layerOnAcrylicFillColorDefault: Color(0x09FFFFFF),
    cardBackgroundFillColorDefault: Color(0x0DFFFFFF),
    cardBackgroundFillColorSecondary: Color(0x08FFFFFF),
    cardStrokeColorDefault: Color(0x19000000),
    controlFillColorDefault: Color(0x0FFFFFFF),
    controlFillColorSecondary: Color(0x15FFFFFF),
    controlFillColorTertiary: Color(0x08FFFFFF),
    controlFillColorDisabled: Color(0x0BFFFFFF),
    controlStrokeColorDefault: Color(0x12FFFFFF),
    controlStrokeColorSecondary: Color(0x18FFFFFF),
    surfaceStrokeColorDefault: Color(0x66757575),
    dividerStrokeColorDefault: Color(0x15FFFFFF),
    textFillColorPrimary: Color(0xFFFFFFFF),
    textFillColorSecondary: Color(0xC5FFFFFF),
    textFillColorTertiary: Color(0x87FFFFFF),
    textFillColorDisabled: Color(0x5DFFFFFF),
    textOnAccentFillColorPrimary: Color(0xFF000000),
    accentFillColorDefault: Color(0xFF4CC2FF),
    accentFillColorSecondary: Color(0xE64CC2FF),
    accentFillColorTertiary: Color(0xCC4CC2FF),
    focusStrokeColorOuter: Color(0xFFFFFFFF),
    focusStrokeColorInner: Color(0xB3000000),
    smokeFillColorDefault: Color(0x4D000000),
    systemFillColorSuccess: Color(0xFF6CCB5F),
    systemFillColorCaution: Color(0xFFFCE100),
    systemFillColorCritical: Color(0xFFFF99A4),
    systemFillColorNeutral: Color(0xFF9D9D9D),
  );

  /// Shorthand for reading the tokens off a BuildContext.
  static FluentColors of(BuildContext context) =>
      Theme.of(context).extension<FluentColors>() ?? light;

  @override
  FluentColors copyWith({
    Color? solidBackgroundFillColorBase,
    Color? solidBackgroundFillColorSecondary,
    Color? solidBackgroundFillColorTertiary,
    Color? solidBackgroundFillColorQuarternary,
    Color? layerFillColorDefault,
    Color? layerOnAcrylicFillColorDefault,
    Color? cardBackgroundFillColorDefault,
    Color? cardBackgroundFillColorSecondary,
    Color? cardStrokeColorDefault,
    Color? controlFillColorDefault,
    Color? controlFillColorSecondary,
    Color? controlFillColorTertiary,
    Color? controlFillColorDisabled,
    Color? controlStrokeColorDefault,
    Color? controlStrokeColorSecondary,
    Color? surfaceStrokeColorDefault,
    Color? dividerStrokeColorDefault,
    Color? textFillColorPrimary,
    Color? textFillColorSecondary,
    Color? textFillColorTertiary,
    Color? textFillColorDisabled,
    Color? textOnAccentFillColorPrimary,
    Color? accentFillColorDefault,
    Color? accentFillColorSecondary,
    Color? accentFillColorTertiary,
    Color? focusStrokeColorOuter,
    Color? focusStrokeColorInner,
    Color? smokeFillColorDefault,
    Color? systemFillColorSuccess,
    Color? systemFillColorCaution,
    Color? systemFillColorCritical,
    Color? systemFillColorNeutral,
  }) {
    return FluentColors(
      solidBackgroundFillColorBase:
          solidBackgroundFillColorBase ?? this.solidBackgroundFillColorBase,
      solidBackgroundFillColorSecondary:
          solidBackgroundFillColorSecondary ??
          this.solidBackgroundFillColorSecondary,
      solidBackgroundFillColorTertiary:
          solidBackgroundFillColorTertiary ??
          this.solidBackgroundFillColorTertiary,
      solidBackgroundFillColorQuarternary:
          solidBackgroundFillColorQuarternary ??
          this.solidBackgroundFillColorQuarternary,
      layerFillColorDefault:
          layerFillColorDefault ?? this.layerFillColorDefault,
      layerOnAcrylicFillColorDefault:
          layerOnAcrylicFillColorDefault ?? this.layerOnAcrylicFillColorDefault,
      cardBackgroundFillColorDefault:
          cardBackgroundFillColorDefault ?? this.cardBackgroundFillColorDefault,
      cardBackgroundFillColorSecondary:
          cardBackgroundFillColorSecondary ??
          this.cardBackgroundFillColorSecondary,
      cardStrokeColorDefault:
          cardStrokeColorDefault ?? this.cardStrokeColorDefault,
      controlFillColorDefault:
          controlFillColorDefault ?? this.controlFillColorDefault,
      controlFillColorSecondary:
          controlFillColorSecondary ?? this.controlFillColorSecondary,
      controlFillColorTertiary:
          controlFillColorTertiary ?? this.controlFillColorTertiary,
      controlFillColorDisabled:
          controlFillColorDisabled ?? this.controlFillColorDisabled,
      controlStrokeColorDefault:
          controlStrokeColorDefault ?? this.controlStrokeColorDefault,
      controlStrokeColorSecondary:
          controlStrokeColorSecondary ?? this.controlStrokeColorSecondary,
      surfaceStrokeColorDefault:
          surfaceStrokeColorDefault ?? this.surfaceStrokeColorDefault,
      dividerStrokeColorDefault:
          dividerStrokeColorDefault ?? this.dividerStrokeColorDefault,
      textFillColorPrimary: textFillColorPrimary ?? this.textFillColorPrimary,
      textFillColorSecondary:
          textFillColorSecondary ?? this.textFillColorSecondary,
      textFillColorTertiary:
          textFillColorTertiary ?? this.textFillColorTertiary,
      textFillColorDisabled:
          textFillColorDisabled ?? this.textFillColorDisabled,
      textOnAccentFillColorPrimary:
          textOnAccentFillColorPrimary ?? this.textOnAccentFillColorPrimary,
      accentFillColorDefault:
          accentFillColorDefault ?? this.accentFillColorDefault,
      accentFillColorSecondary:
          accentFillColorSecondary ?? this.accentFillColorSecondary,
      accentFillColorTertiary:
          accentFillColorTertiary ?? this.accentFillColorTertiary,
      focusStrokeColorOuter:
          focusStrokeColorOuter ?? this.focusStrokeColorOuter,
      focusStrokeColorInner:
          focusStrokeColorInner ?? this.focusStrokeColorInner,
      smokeFillColorDefault:
          smokeFillColorDefault ?? this.smokeFillColorDefault,
      systemFillColorSuccess:
          systemFillColorSuccess ?? this.systemFillColorSuccess,
      systemFillColorCaution:
          systemFillColorCaution ?? this.systemFillColorCaution,
      systemFillColorCritical:
          systemFillColorCritical ?? this.systemFillColorCritical,
      systemFillColorNeutral:
          systemFillColorNeutral ?? this.systemFillColorNeutral,
    );
  }

  @override
  FluentColors lerp(covariant FluentColors? other, double t) {
    if (other == null) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return FluentColors(
      solidBackgroundFillColorBase: mix(
        solidBackgroundFillColorBase,
        other.solidBackgroundFillColorBase,
      ),
      solidBackgroundFillColorSecondary: mix(
        solidBackgroundFillColorSecondary,
        other.solidBackgroundFillColorSecondary,
      ),
      solidBackgroundFillColorTertiary: mix(
        solidBackgroundFillColorTertiary,
        other.solidBackgroundFillColorTertiary,
      ),
      solidBackgroundFillColorQuarternary: mix(
        solidBackgroundFillColorQuarternary,
        other.solidBackgroundFillColorQuarternary,
      ),
      layerFillColorDefault: mix(
        layerFillColorDefault,
        other.layerFillColorDefault,
      ),
      layerOnAcrylicFillColorDefault: mix(
        layerOnAcrylicFillColorDefault,
        other.layerOnAcrylicFillColorDefault,
      ),
      cardBackgroundFillColorDefault: mix(
        cardBackgroundFillColorDefault,
        other.cardBackgroundFillColorDefault,
      ),
      cardBackgroundFillColorSecondary: mix(
        cardBackgroundFillColorSecondary,
        other.cardBackgroundFillColorSecondary,
      ),
      cardStrokeColorDefault: mix(
        cardStrokeColorDefault,
        other.cardStrokeColorDefault,
      ),
      controlFillColorDefault: mix(
        controlFillColorDefault,
        other.controlFillColorDefault,
      ),
      controlFillColorSecondary: mix(
        controlFillColorSecondary,
        other.controlFillColorSecondary,
      ),
      controlFillColorTertiary: mix(
        controlFillColorTertiary,
        other.controlFillColorTertiary,
      ),
      controlFillColorDisabled: mix(
        controlFillColorDisabled,
        other.controlFillColorDisabled,
      ),
      controlStrokeColorDefault: mix(
        controlStrokeColorDefault,
        other.controlStrokeColorDefault,
      ),
      controlStrokeColorSecondary: mix(
        controlStrokeColorSecondary,
        other.controlStrokeColorSecondary,
      ),
      surfaceStrokeColorDefault: mix(
        surfaceStrokeColorDefault,
        other.surfaceStrokeColorDefault,
      ),
      dividerStrokeColorDefault: mix(
        dividerStrokeColorDefault,
        other.dividerStrokeColorDefault,
      ),
      textFillColorPrimary: mix(
        textFillColorPrimary,
        other.textFillColorPrimary,
      ),
      textFillColorSecondary: mix(
        textFillColorSecondary,
        other.textFillColorSecondary,
      ),
      textFillColorTertiary: mix(
        textFillColorTertiary,
        other.textFillColorTertiary,
      ),
      textFillColorDisabled: mix(
        textFillColorDisabled,
        other.textFillColorDisabled,
      ),
      textOnAccentFillColorPrimary: mix(
        textOnAccentFillColorPrimary,
        other.textOnAccentFillColorPrimary,
      ),
      accentFillColorDefault: mix(
        accentFillColorDefault,
        other.accentFillColorDefault,
      ),
      accentFillColorSecondary: mix(
        accentFillColorSecondary,
        other.accentFillColorSecondary,
      ),
      accentFillColorTertiary: mix(
        accentFillColorTertiary,
        other.accentFillColorTertiary,
      ),
      focusStrokeColorOuter: mix(
        focusStrokeColorOuter,
        other.focusStrokeColorOuter,
      ),
      focusStrokeColorInner: mix(
        focusStrokeColorInner,
        other.focusStrokeColorInner,
      ),
      smokeFillColorDefault: mix(
        smokeFillColorDefault,
        other.smokeFillColorDefault,
      ),
      systemFillColorSuccess: mix(
        systemFillColorSuccess,
        other.systemFillColorSuccess,
      ),
      systemFillColorCaution: mix(
        systemFillColorCaution,
        other.systemFillColorCaution,
      ),
      systemFillColorCritical: mix(
        systemFillColorCritical,
        other.systemFillColorCritical,
      ),
      systemFillColorNeutral: mix(
        systemFillColorNeutral,
        other.systemFillColorNeutral,
      ),
    );
  }
}
