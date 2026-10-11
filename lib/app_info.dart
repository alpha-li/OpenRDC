/// Application identity, shown in Settings → About.
library;

/// The application version.
///
/// Mirrors `version:` in pubspec.yaml. Keeping it here rather than reading it
/// at runtime is a deliberate trade: the alternative is another native plugin
/// (`package_info_plus`) whose only job would be to read a string this app
/// already knows at build time. **Bump both together** — the pubspec value is
/// what packages and installers report, and this is what the user sees.
const String kAppVersion = '0.1.0';
