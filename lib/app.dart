import 'package:flutter/material.dart';

import 'data/connection_store.dart';
import 'data/credential_vault.dart';
import 'data/preferences_store.dart';
import 'data/storage_paths.dart';
import 'engine/rdc_engine.dart';
import 'l10n/generated/app_localizations.dart';
import 'features/connection_center/connection_center_page.dart';
import 'features/diagnostics/bridge_probe_page.dart';
import 'features/session/credential_prompt.dart';
import 'features/session/session_page.dart';
import 'features/settings/settings_page.dart';
import 'models/credential.dart';
import 'models/pc_connection.dart';
import 'theme/fluent_colors.dart';

/// Where the app is sent on launch, decided from the command line.
sealed class StartupMode {
  const StartupMode();
}

/// Normal launch: the connection centre.
class ConnectionCentreStartup extends StartupMode {
  const ConnectionCentreStartup();
}

/// `--diagnostics`: the native bridge self-check.
class DiagnosticsStartup extends StartupMode {
  const DiagnosticsStartup();
}

/// `--connect host[:port]`: open a session straight away, skipping the UI.
///
/// Intended for debugging a host without clicking through the connection
/// centre. The password is taken from the `OPENRDC_PASSWORD` environment
/// variable rather than an argument, so it does not end up in the process list.
class DirectConnectStartup extends StartupMode {
  const DirectConnectStartup({
    required this.hostname,
    required this.port,
    this.username = '',
    this.password = '',
    this.domain = '',
    this.ignoreCertificate = false,
    this.startFullScreen = false,
  });

  final String hostname;
  final int port;
  final String username;
  final String password;
  final String domain;
  final bool ignoreCertificate;
  final bool startFullScreen;
}

class OpenRdcApp extends StatefulWidget {
  const OpenRdcApp({
    super.key,
    this.store,
    this.vault,
    this.preferences,
    this.startup = const ConnectionCentreStartup(),
  });

  /// Injectable so tests can supply a temporary store.
  final ConnectionStore? store;

  /// Injectable so tests need not touch the platform secret store.
  final CredentialVault? vault;

  /// Injectable for tests, which supply a temporary file rather than touching
  /// the real preferences.
  final PreferencesStore? preferences;

  final StartupMode startup;

  @override
  State<OpenRdcApp> createState() => _OpenRdcAppState();
}

class _OpenRdcAppState extends State<OpenRdcApp> {
  late final ConnectionStore _store =
      widget.store ?? ConnectionStore(StoragePaths.defaultForPlatform());
  late final bool _ownsStore = widget.store == null;

  /// One engine for the whole application. It is a thin façade over a native
  /// singleton, so several instances would work, but keeping one makes who owns
  /// the session obvious.
  late final RdcEngine _engine = RdcEngine.create();

  /// Navigation from the app state has to go through this.
  ///
  /// This state's own `context` is the context of the widget that *contains*
  /// the MaterialApp, so it sits above the Navigator and `Navigator.of` on it
  /// throws. The failure is silent when the call is one link down an unawaited
  /// callback: the tap handler has nowhere to report it, so clicking a card
  /// simply did nothing at all.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// Backed by the operating system's secret store. Reports not persistent when
  /// the engine is unavailable, which is what the prompts say rather than
  /// pretending the password was saved.
  late final CredentialVault _vault =
      widget.vault ?? EngineCredentialVault(_engine);

  /// App-wide preferences, kept apart from the connection store: losing a theme
  /// choice is not the same kind of loss as losing the user's saved PCs, so
  /// they are separate files with separate failure handling.
  late final PreferencesStore _preferences =
      widget.preferences ?? PreferencesStore(StoragePaths.defaultForPlatform());
  late final bool _ownsPreferences = widget.preferences == null;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // The theme comes from the preferences, so a change has to rebuild the
    // MaterialApp above every page.
    _preferences.addListener(_onPreferencesChanged);
    _load();
  }

  void _onPreferencesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (_ownsStore) {
      _store.dispose();
    }
    _preferences.removeListener(_onPreferencesChanged);
    if (_ownsPreferences) {
      _preferences.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([_store.load(), _preferences.load()]);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  /// Builds the gateway settings for [connection], if it uses one.
  ///
  /// The gateway's own password comes from the vault under the gateway's
  /// credential, which may be the same record the PC uses -- the "use PC
  /// credential" case -- so it is looked up by whatever id the gateway names.
  Future<RdcGatewayRequest?> _resolveGateway(PcConnection connection) async {
    final gatewayId = connection.gatewayId;
    if (gatewayId == null) {
      return null;
    }
    final gateway = _store.gatewayById(gatewayId);
    if (gateway == null) {
      return null;
    }

    var username = '';
    var password = '';
    var domain = '';
    if (gateway.credentialId != null) {
      final credential = _store.credentialById(gateway.credentialId!);
      if (credential != null) {
        username = credential.username;
        domain = credential.domain;
        password = await _vault.retrieve(credential.id) ?? '';
      }
    }

    return RdcGatewayRequest(
      hostname: gateway.effectiveHostname,
      port: gateway.effectivePort,
      username: username,
      password: password,
      domain: domain,
      bypassForLocalAddresses: gateway.bypassForLocalAddresses,
    );
  }

  /// Opens the settings page.
  Future<void> _openSettings() async {
    await _navigatorKey.currentState?.push<void>(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          store: _store,
          preferences: _preferences,
          vault: _vault,
          engine: _engine,
        ),
      ),
    );
  }

  /// Opens a session, resolving or collecting credentials first.
  Future<void> _openSession(PcConnection connection) async {
    var username = '';
    var password = '';
    var domain = '';

    final credential = connection.credentialId == null
        ? null
        : _store.credentialById(connection.credentialId!);

    if (connection.credentialMode == CredentialMode.saved &&
        credential != null) {
      username = credential.username;
      domain = credential.domain;
      password = await _vault.retrieve(credential.id) ?? '';
    }

    if (password.isEmpty && mounted) {
      // Saving is only offered when there is a credential record to save
      // against. A connection set to ask every time has nowhere to put the
      // answer, so offering it would be a promise the app cannot keep.
      final canRemember = _vault.isPersistent && credential != null;

      // Checked on the context itself, not just on this State: the vault read
      // above is an await, and the navigator can be gone by now even while this
      // State is still alive.
      final navigator = _navigatorKey.currentContext;
      if (navigator == null || !navigator.mounted) {
        return;
      }

      final entered = await showDialog<EnteredCredentials>(
        context: navigator,
        builder: (context) => CredentialPrompt(
          title: connection.displayName,
          initialUsername: username.isEmpty
              ? credential?.qualifiedUsername ?? ''
              : '',
          vaultIsPersistent: _vault.isPersistent,
          canRemember: canRemember,
          message: credential == null
              ? null
              : AppLocalizations.of(context).credentialPasswordNotSaved,
        ),
      );
      if (entered == null) {
        return;
      }
      username = entered.username;
      password = entered.password;
      domain = entered.domain;

      if (entered.remember && credential != null) {
        await _vault.store(credential.id, password);
      }
    }

    // Resolved here because this is the layer that can reach both the store and
    // the vault, and the session needs the gateway's own credentials as well as
    // its address.
    final gateway = await _resolveGateway(connection);

    await _store.markConnected(connection.id, at: DateTime.now());
    if (!mounted) {
      return;
    }
    await _navigatorKey.currentState?.push<void>(
      MaterialPageRoute(
        builder: (context) => SessionPage(
          connection: connection,
          username: username,
          password: password,
          domain: domain,
          gateway: gateway,
        ),
      ),
    );
  }

  /// Builds the ad-hoc connection used by `--connect`.
  PcConnection _directConnection(DirectConnectStartup direct) => PcConnection(
    id: 'direct',
    hostname: direct.hostname,
    port: direct.port,
    friendlyName: direct.hostname,
    display: PcDisplaySettings(
      // Follow the window, which is what makes a direct connection behave like
      // a desktop client rather than a fixed-size one.
      updateResolutionOnResize: true,
      startFullScreen: direct.startFullScreen,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenRDC',
      // Chinese is the template locale, so it is the fallback when the system
      // language is one the app does not have.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: buildFluentTheme(Brightness.light, FluentColors.light),
      darkTheme: buildFluentTheme(Brightness.dark, FluentColors.dark),
      themeMode: _preferences.preferences.themeMode,
      navigatorKey: _navigatorKey,
      home: switch (widget.startup) {
        DiagnosticsStartup() => const BridgeProbePage(),
        DirectConnectStartup(
          :final hostname,
          :final port,
          :final username,
          :final password,
          :final domain,
          :final ignoreCertificate,
          :final startFullScreen,
        ) =>
          SessionPage(
            connection: _directConnection(
              DirectConnectStartup(
                hostname: hostname,
                port: port,
                startFullScreen: startFullScreen,
              ),
            ),
            username: username,
            password: password,
            domain: domain,
            ignoreCertificate: ignoreCertificate,
          ),
        ConnectionCentreStartup() =>
          _loading
              ? const _LoadingScreen()
              : ConnectionCenterPage(
                  store: _store,
                  vault: _vault,
                  onConnect: _openSession,
                  onOpenSettings: _openSettings,
                ),
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Scaffold(
      backgroundColor: colors.solidBackgroundFillColorBase,
      body: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: colors.accentFillColorDefault,
          ),
        ),
      ),
    );
  }
}

ThemeData buildFluentTheme(Brightness brightness, FluentColors colors) {
  // Segoe UI Variable is the Windows 11 UI font; the Chinese fallback is
  // Microsoft YaHei UI. Flutter takes a fallback list and the platform resolves
  // whichever is actually installed.
  const fontFamily = 'Segoe UI Variable Text';
  const fontFamilyFallback = <String>[
    'Segoe UI',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
  ];

  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.accentFillColorDefault,
      brightness: brightness,
    ),
    scaffoldBackgroundColor: colors.solidBackgroundFillColorBase,
  );

  return base.copyWith(extensions: [colors]);
}
