/// Shared scaffolding for widget tests.
library;

import 'package:flutter/material.dart';
import 'package:openrdc/app.dart';
import 'package:openrdc/l10n/generated/app_localizations.dart';
import 'package:openrdc/theme/fluent_colors.dart';

/// Wraps [home] in a MaterialApp configured the way the real one is.
///
/// Tests assert on Chinese text, and the test binding's default locale is
/// English, so without pinning the locale here every string assertion would
/// silently start checking the English translation instead. Pinning it also
/// keeps the assertions readable to whoever wrote them.
Widget testApp({required Widget home, Locale locale = const Locale('zh')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildFluentTheme(Brightness.light, FluentColors.light),
      home: home,
    );
