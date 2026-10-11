/// Application-level preferences: the settings that belong to the app rather
/// than to any one connection.
///
/// Kept in its own file rather than mixed into the connection store, because
/// the two have different lifetimes and different failure modes: losing a
/// preference costs the user a theme choice, losing a connection costs them
/// their saved PCs. Corrupting one must not endanger the other.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'storage_paths.dart';

@immutable
class AppPreferences {
  const AppPreferences({this.themeMode = ThemeMode.system});

  /// Light, dark, or whatever the operating system says.
  final ThemeMode themeMode;

  AppPreferences copyWith({ThemeMode? themeMode}) =>
      AppPreferences(themeMode: themeMode ?? this.themeMode);

  Map<String, Object?> toJson() => {'themeMode': themeMode.name};

  /// Unknown or malformed values fall back rather than throwing: a preferences
  /// file the user has hand-edited should not stop the app starting.
  factory AppPreferences.fromJson(Map<String, Object?> json) {
    final mode = json['themeMode'];
    return AppPreferences(
      themeMode: ThemeMode.values.firstWhere(
        (candidate) => candidate.name == mode,
        orElse: () => ThemeMode.system,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppPreferences && other.themeMode == themeMode;

  @override
  int get hashCode => themeMode.hashCode;
}

class PreferencesStore extends ChangeNotifier {
  PreferencesStore(this.paths);

  final StoragePaths paths;

  AppPreferences _preferences = const AppPreferences();
  bool _loaded = false;

  AppPreferences get preferences => _preferences;
  bool get isLoaded => _loaded;

  /// Reads the file, or starts from defaults when there is none.
  ///
  /// A missing file is the normal first-run case. A corrupt one is discarded in
  /// place rather than quarantined, unlike the connection store: the worst it
  /// costs the user is re-picking a theme, and leaving a `.corrupt` file behind
  /// for that would be clutter.
  Future<void> load() async {
    final file = paths.preferencesFileHandle;
    try {
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, Object?>) {
            _preferences = AppPreferences.fromJson(decoded);
          }
        }
      }
    } on Object catch (error) {
      debugPrint('preferences: discarding unreadable file ($error)');
      _preferences = const AppPreferences();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_preferences.themeMode == mode) {
      return;
    }
    _preferences = _preferences.copyWith(themeMode: mode);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      await paths.ensureExists();
      final file = paths.preferencesFileHandle;
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_preferences.toJson()),
        flush: true,
      );
      if (await file.exists()) {
        await file.delete();
      }
      await temp.rename(file.path);
    } on Object catch (error) {
      // The theme simply will not survive a restart. Not worth interrupting the
      // user over, but worth leaving a trace of.
      debugPrint('preferences: could not save ($error)');
    }
  }
}
