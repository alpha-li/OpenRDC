import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:openrdc/data/preferences_store.dart';
import 'package:openrdc/data/storage_paths.dart';

void main() {
  late Directory tempDir;
  late StoragePaths paths;
  late PreferencesStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('openrdc_prefs_test');
    paths = StoragePaths.forDirectory(tempDir);
    store = PreferencesStore(paths);
  });

  tearDown(() async {
    store.dispose();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('load', () {
    test('starts from defaults when there is no file', () async {
      await store.load();

      expect(store.isLoaded, isTrue);
      expect(store.preferences.themeMode, ThemeMode.system);
    });

    test('reads a stored mode back', () async {
      await paths.ensureExists();
      await File(
        paths.preferencesFile,
      ).writeAsString(jsonEncode({'themeMode': 'dark'}));

      await store.load();

      expect(store.preferences.themeMode, ThemeMode.dark);
    });

    test('discards a corrupt file rather than failing to start', () async {
      // Unlike the connection store, this one is not quarantined: the worst a
      // lost preference costs is re-picking a theme, and leaving a
      // .corrupt file behind for that would be clutter.
      await paths.ensureExists();
      await File(paths.preferencesFile).writeAsString('{ not json');

      await store.load();

      expect(store.isLoaded, isTrue);
      expect(store.preferences.themeMode, ThemeMode.system);
    });

    test('falls back when the stored mode is not a known one', () async {
      await paths.ensureExists();
      await File(
        paths.preferencesFile,
      ).writeAsString(jsonEncode({'themeMode': 'sepia'}));

      await store.load();

      expect(store.preferences.themeMode, ThemeMode.system);
    });
  });

  group('setThemeMode', () {
    test('survives a restart', () async {
      await store.load();
      await store.setThemeMode(ThemeMode.dark);

      final reloaded = PreferencesStore(paths);
      await reloaded.load();

      expect(reloaded.preferences.themeMode, ThemeMode.dark);
      reloaded.dispose();
    });

    test('notifies listeners so the theme updates without a restart', () async {
      await store.load();
      var notifications = 0;
      store.addListener(() => notifications++);

      await store.setThemeMode(ThemeMode.light);

      expect(notifications, greaterThan(0));
    });

    test('setting the same mode again is a no-op', () async {
      await store.load();
      var notifications = 0;
      store.addListener(() => notifications++);

      await store.setThemeMode(ThemeMode.system);

      expect(notifications, 0, reason: '相同取值不应触发重建');
    });

    test('leaves no temporary file behind', () async {
      await store.load();
      await store.setThemeMode(ThemeMode.light);

      final leftovers = tempDir.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.tmp'),
      );
      expect(leftovers, isEmpty);
    });
  });
}
