/// Resolves where the application keeps its data, without pulling in a plugin.
///
/// `path_provider` would be the obvious choice, but it is another native plugin
/// and therefore another platform build to keep working. The per-platform
/// conventions are simple enough to read straight out of the environment.
library;

import 'dart:io';

/// Directory and file layout under the user's application data directory.
class StoragePaths {
  const StoragePaths(this.dataDirectory);

  /// Overrides the platform default. Tests point this at a temporary directory.
  factory StoragePaths.forDirectory(Directory directory) =>
      StoragePaths(directory.path);

  /// The conventional location for this platform, under an `OpenRDC` folder.
  factory StoragePaths.defaultForPlatform() =>
      StoragePaths(_defaultDataDirectory());

  /// Where all application data lives.
  final String dataDirectory;

  /// Saved PCs, credentials and gateways.
  String get connectionsFile => _join(dataDirectory, 'connections.json');

  /// Window geometry, view mode and other small preferences.
  String get preferencesFile => _join(dataDirectory, 'preferences.json');

  /// A per-user, per-host thumbnail of the last session, used by the card grid.
  String thumbnailFor(String connectionId) =>
      _join(_join(dataDirectory, 'thumbnails'), '$connectionId.png');

  File get connectionsFileHandle => File(connectionsFile);

  File get preferencesFileHandle => File(preferencesFile);

  /// Creates the data directory (and the thumbnail directory) if needed.
  Future<void> ensureExists() async {
    await Directory(dataDirectory).create(recursive: true);
    await Directory(_join(dataDirectory, 'thumbnails')).create(recursive: true);
  }

  static String _join(String a, String b) => a.endsWith(Platform.pathSeparator)
      ? '$a$b'
      : '$a${Platform.pathSeparator}$b';

  static String _defaultDataDirectory() {
    final environment = Platform.environment;

    if (Platform.isWindows) {
      // Roaming, so the connections follow the user between machines in a
      // domain — which is what the Windows App does.
      final appData = environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return _join(appData, 'OpenRDC');
      }
      return _join(Directory.current.path, '.openrdc');
    }

    if (Platform.isMacOS) {
      final home = environment['HOME'] ?? Directory.current.path;
      return _join(
        _join(_join(home, 'Library'), 'Application Support'),
        'OpenRDC',
      );
    }

    // Linux and anything else that follows the XDG base directory spec.
    final xdg = environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      return _join(xdg, 'openrdc');
    }
    final home = environment['HOME'] ?? Directory.current.path;
    return _join(_join(home, '.config'), 'openrdc');
  }
}
