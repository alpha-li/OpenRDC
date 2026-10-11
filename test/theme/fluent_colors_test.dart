import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openrdc/theme/fluent_colors.dart';

void main() {
  group('FluentColors', () {
    test('pins the values the Windows App look depends on', () {
      // These are the WinUI theme resources verbatim. Spot-checking a few
      // catches the failure mode that matters most: someone "tidying" the
      // translucent tokens into opaque approximations, which quietly breaks the
      // layered Mica look.
      expect(
        FluentColors.light.solidBackgroundFillColorBase,
        const Color(0xFFF3F3F3),
      );
      expect(
        FluentColors.dark.solidBackgroundFillColorBase,
        const Color(0xFF202020),
      );
      expect(
        FluentColors.light.solidBackgroundFillColorSecondary,
        const Color(0xFFEEEEEE),
      );
      expect(
        FluentColors.dark.solidBackgroundFillColorSecondary,
        const Color(0xFF1C1C1C),
      );

      // Text tokens carry alpha rather than being solid black/white.
      expect(FluentColors.light.textFillColorPrimary, const Color(0xE4000000));
      expect(FluentColors.dark.textFillColorPrimary, const Color(0xFFFFFFFF));
      expect(
        FluentColors.light.textFillColorSecondary,
        const Color(0x9E000000),
      );

      // Card fills are translucent by design; the light one is white-ish.
      expect(
        FluentColors.light.cardBackgroundFillColorDefault,
        const Color(0xB3FFFFFF),
      );
      expect(
        FluentColors.dark.cardBackgroundFillColorDefault,
        const Color(0x0DFFFFFF),
      );
    });

    test(
      'uses the Windows 11 accent rather than the older Windows 10 blue',
      () {
        expect(
          FluentColors.light.accentFillColorDefault,
          const Color(0xFF005FB8),
        );
        expect(
          FluentColors.dark.accentFillColorDefault,
          const Color(0xFF4CC2FF),
        );
      },
    );

    test('keeps hover and pressed accent distinct from rest', () {
      final light = FluentColors.light;
      expect(
        light.accentFillColorSecondary,
        isNot(light.accentFillColorDefault),
      );
      expect(
        light.accentFillColorTertiary,
        isNot(light.accentFillColorDefault),
      );
      // Same hue, decreasing opacity.
      expect(
        light.accentFillColorSecondary.a,
        lessThan(light.accentFillColorDefault.a),
      );
      expect(
        light.accentFillColorTertiary.a,
        lessThan(light.accentFillColorSecondary.a),
      );
    });

    test('copyWith replaces only what it is given', () {
      const replacement = Color(0xFF123456);
      final updated = FluentColors.light.copyWith(
        accentFillColorDefault: replacement,
      );
      expect(updated.accentFillColorDefault, replacement);
      expect(
        updated.textFillColorPrimary,
        FluentColors.light.textFillColorPrimary,
      );
    });

    test('lerp returns the source when the other side is null', () {
      expect(FluentColors.light.lerp(null, 0.5), FluentColors.light);
    });

    test('lerp interpolates rather than snapping', () {
      final midway = FluentColors.light.lerp(FluentColors.dark, 0.5);
      expect(
        midway.solidBackgroundFillColorBase,
        isNot(FluentColors.light.solidBackgroundFillColorBase),
      );
      expect(
        midway.solidBackgroundFillColorBase,
        isNot(FluentColors.dark.solidBackgroundFillColorBase),
      );
    });

    testWidgets('of() reads the extension off the ambient theme', (
      tester,
    ) async {
      late FluentColors seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [FluentColors.dark]),
          home: Builder(
            builder: (context) {
              seen = FluentColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, FluentColors.dark);
    });

    testWidgets('of() falls back to light when the theme has no extension', (
      tester,
    ) async {
      late FluentColors seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen = FluentColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, FluentColors.light);
    });
  });
}
