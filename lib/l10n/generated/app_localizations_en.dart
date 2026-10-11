// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OpenRDC';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get back => 'Back';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get refresh => 'Refresh';

  @override
  String get connect => 'Connect';

  @override
  String get close => 'Close';

  @override
  String get stop => 'Stop';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get optional => 'Optional';

  @override
  String get tabHome => 'Home';

  @override
  String get tabDevices => 'Devices';

  @override
  String get tabFavorites => 'Favorites';

  @override
  String get search => 'Search';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortRecency => 'Recently used';

  @override
  String get sortName => 'Name';

  @override
  String get sortManual => 'Manual';

  @override
  String get switchToList => 'Switch to list view';

  @override
  String get switchToGrid => 'Switch to grid view';

  @override
  String get addPc => 'Add PC';

  @override
  String get moreOptions => 'More options';

  @override
  String get emptyNoDevicesTitle => 'No PCs saved yet';

  @override
  String get emptyNoDevicesBody => 'Add a PC to start a remote connection.';

  @override
  String get emptyFavoritesTitle => 'Nothing here yet';

  @override
  String get emptyFavoritesBody => 'PCs you add to Favorites appear here.';

  @override
  String get emptySearchTitle => 'No matches';

  @override
  String emptySearchBody(String query) {
    return 'No PC matches \"$query\".';
  }

  @override
  String get cardRemoteDesktop => 'Remote desktop';

  @override
  String get cardAddToFavorites => 'Add to favorites';

  @override
  String get cardRemoveFromFavorites => 'Remove from favorites';

  @override
  String get deletePcTitle => 'Delete this PC?';

  @override
  String deletePcBody(String name) {
    return '\"$name\" will be removed from the connection centre. The remote PC itself is not affected.';
  }

  @override
  String get editorAddPcTitle => 'Add PC';

  @override
  String get editorEditPcTitle => 'Edit PC';

  @override
  String get tabGeneral => 'General';

  @override
  String get tabDisplay => 'Display';

  @override
  String get tabDevicesAndAudio => 'Devices & Audio';

  @override
  String get tabFolders => 'Folders';

  @override
  String get fieldPcName => 'PC name';

  @override
  String get fieldPcNamePlaceholder =>
      'Host name or IP address, optionally with a port';

  @override
  String get fieldPort => 'Port';

  @override
  String get fieldFriendlyName => 'Friendly name';

  @override
  String get fieldFriendlyNamePlaceholder => 'Leave blank to show the PC name';

  @override
  String get fieldGroup => 'Group';

  @override
  String get validationPcNameRequired => 'Enter a PC name or IP address';

  @override
  String get credentials => 'Credentials';

  @override
  String get fieldUserAccount => 'User account';

  @override
  String get askEveryTime => 'Ask when required';

  @override
  String get newCredential => 'New credential';

  @override
  String get editCredential => 'Edit credential';

  @override
  String get credentialUsername => 'User name';

  @override
  String get credentialUsernamePlaceholder => 'User name, or DOMAIN\\user';

  @override
  String get credentialPassword => 'Password';

  @override
  String get credentialFriendlyNamePlaceholder =>
      'Optional, to recognise it in a list';

  @override
  String get validationUsernameRequired => 'Enter a user name';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get vaultNotPersistentWarning =>
      'This build is not connected to the system credential store, so the password lasts only until the app closes.';

  @override
  String get rememberPassword => 'Remember password';

  @override
  String get rememberPasswordBody =>
      'Save it to the system credential store and stop being asked';

  @override
  String get passwordOnlyThisSession =>
      'The password is kept for this session only and will be needed again after a restart.';

  @override
  String get credentialPasswordNotSaved =>
      'No password is saved for this credential yet.';

  @override
  String get storeErrorUnreadable =>
      'Saved connections could not be read, so the app started empty. The original file was kept.';

  @override
  String get storeErrorMalformed =>
      'The saved connections file is not valid, so the app started empty. The original file was kept.';

  @override
  String get storeErrorUnsupportedVersion =>
      'The connections file was written by a newer version of the app. Update to open it.';

  @override
  String get storeErrorWriteFailed =>
      'The change could not be saved, so it is not on disk.';

  @override
  String get gateway => 'Gateway';

  @override
  String get newGateway => 'New gateway';

  @override
  String get editGateway => 'Edit gateway';

  @override
  String get gatewayAddress => 'Gateway address';

  @override
  String get gatewayAddressPlaceholder => 'e.g. gateway.example.com';

  @override
  String get gatewayCredentials => 'Gateway credentials';

  @override
  String get gatewaySameAsPc => 'Same as the PC';

  @override
  String get fieldBypassGateway => 'Bypass gateway for local addresses';

  @override
  String get fieldBypassGatewayBody =>
      'Connect directly to PCs on the local network instead of through the gateway';

  @override
  String get validationGatewayRequired => 'Enter a gateway address';

  @override
  String get session => 'Session';

  @override
  String get fieldReconnect => 'Reconnect if the connection is dropped';

  @override
  String get fieldAdminSession => 'Connect to an admin session';

  @override
  String get fieldAdminSessionBody =>
      'Sign in to the console session, for troubleshooting';

  @override
  String get fieldSwapMouseButtons => 'Swap mouse buttons';

  @override
  String get fieldResolution => 'Resolution';

  @override
  String get fieldColorQuality => 'Color quality';

  @override
  String get colorQualityHighest => 'Highest quality (32-bit)';

  @override
  String get colorQualityEnhanced => 'Enhanced color (24-bit)';

  @override
  String get colorQualityHigh => 'High color (16-bit)';

  @override
  String get displayWindowBehaviour => 'Window behaviour';

  @override
  String get fieldStartFullScreen => 'Start session in full screen';

  @override
  String get fieldFitToWindow => 'Fit session to window';

  @override
  String get fieldFitToWindowBody =>
      'Scale the picture to fill the window; the remote resolution is unchanged';

  @override
  String get fieldUpdateResolutionOnResize => 'Update the resolution on resize';

  @override
  String get fieldUpdateResolutionOnResizeBody =>
      'Ask the remote PC to change resolution when the window changes';

  @override
  String get clipboard => 'Clipboard';

  @override
  String get fieldClipboardRedirection => 'Clipboard redirection';

  @override
  String get clipboardBidirectional => 'Both directions';

  @override
  String get clipboardLocalToRemote => 'Local to remote only';

  @override
  String get clipboardRemoteToLocal => 'Remote to local only';

  @override
  String get clipboardDisabled => 'Disabled';

  @override
  String get audio => 'Audio';

  @override
  String get fieldAudioPlayback => 'Play sound';

  @override
  String get audioOnThisComputer => 'On this computer';

  @override
  String get audioOnRemotePc => 'On the remote PC';

  @override
  String get audioNever => 'Never';

  @override
  String get devices => 'Devices';

  @override
  String get fieldRedirectDrives => 'Drives';

  @override
  String get redirectedFolders => 'Redirected folders';

  @override
  String get foldersEmpty =>
      'No folders added. Once added, a local folder appears as a network drive in the remote session.';

  @override
  String get addFolder => 'Add folder';

  @override
  String get folderPathPlaceholder => 'e.g. D:\\Projects';

  @override
  String get folderReadOnly => 'Read-only';

  @override
  String get sessionMinimize => 'Minimize';

  @override
  String get sessionFullScreen => 'Full screen (Ctrl+Alt+Enter)';

  @override
  String get sessionRestoreWindow => 'Restore the window size (Ctrl+Alt+Enter)';

  @override
  String get sessionPinBar => 'Pin the connection bar';

  @override
  String get sessionUnpinBar => 'Unpin the connection bar';

  @override
  String get sessionOptions => 'Session options';

  @override
  String get sessionSendCad => 'Send Ctrl+Alt+Del';

  @override
  String get sessionReconnect => 'Reconnect';

  @override
  String get sessionDisconnect => 'Disconnect';

  @override
  String get sessionEngineUnavailable =>
      'The remote desktop engine is unavailable';

  @override
  String get statusIdle => 'Idle';

  @override
  String get statusConnecting => 'Connecting';

  @override
  String get statusAuthenticating => 'Verifying identity';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusDisconnecting => 'Disconnecting';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get statusFailed => 'Connection failed';

  @override
  String get certificateUntrustedTitle =>
      'The identity of the remote computer cannot be verified. Connect anyway?';

  @override
  String get certificateChangedTitle => 'The saved certificate has changed';

  @override
  String get certificateChangedBody =>
      'The certificate this computer presented differs from the one saved earlier. If you did not expect that -- a reinstall, a renewed certificate -- it may also mean someone is intercepting your connection.';

  @override
  String get certificateNameMismatchTitle =>
      'The certificate does not name this computer';

  @override
  String get certificateNameMismatchBody =>
      'The certificate was not issued for this address. That is normal if the computer was renamed or readdressed; otherwise it means you are not connecting to the machine it claims to be.';

  @override
  String get certificateRequestedHost => 'Remote computer requested';

  @override
  String get certificateName => 'Name in the certificate';

  @override
  String get certificateNoName => '(the certificate carries no name)';

  @override
  String get certificateIssuer => 'Issued by';

  @override
  String get certificatePreviousFingerprint => 'Previous fingerprint';

  @override
  String get certificateCurrentFingerprint => 'Current fingerprint';

  @override
  String get certificateFingerprint => 'Fingerprint';

  @override
  String get certificateNone => '(none)';

  @override
  String get certificateAcceptChanged =>
      'Choosing Yes accepts the new certificate and replaces the saved one.';

  @override
  String get certificateAcceptRemembered =>
      'Choosing Yes remembers this computer\'s certificate and stops asking.';

  @override
  String get settings => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeMode => 'App mode';

  @override
  String get settingsThemeSystem => 'Use system setting';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsUserAccounts => 'User accounts';

  @override
  String get settingsUserAccountsBody =>
      'Saved credentials are used to sign in to remote PCs. Passwords live in the system credential store and can be deleted here or from the system\'s own credential screen.';

  @override
  String get settingsAccountsEmpty => 'No credentials saved yet.';

  @override
  String get accountDeleteTitle => 'Delete this credential?';

  @override
  String accountDeleteBody(String name) {
    return 'The password for \"$name\" will be removed from the system credential store. Connections using it will ask each time instead.';
  }

  @override
  String get settingsGateways => 'Gateways';

  @override
  String get settingsGatewaysBody =>
      'A gateway relays remote connections, for reaching PCs on an internal network.';

  @override
  String get settingsGatewaysEmpty => 'No gateways saved yet.';

  @override
  String get gatewayDeleteTitle => 'Delete this gateway?';

  @override
  String gatewayDeleteBody(String name) {
    return '\"$name\" will be removed. Connections still pointing at it will connect directly instead.';
  }

  @override
  String get settingsAbout => 'About';

  @override
  String get aboutVersion => 'App version';

  @override
  String get aboutEngine => 'Remote desktop engine';

  @override
  String get aboutEngineUnavailable => 'Unavailable';

  @override
  String get errorConnectFailed =>
      'Could not reach the remote PC. Check that the address and port are right and that the network is reachable.';

  @override
  String get errorTlsFailed =>
      'Could not establish a secure connection to the remote PC. Its certificate may be at fault, or something in between may be interfering.';

  @override
  String get errorPasswordExpired =>
      'The account password has expired or must be changed. Deal with it on the remote PC, then connect again.';

  @override
  String get errorAuthFailed =>
      'The sign-in was refused. Check the user name and password, and whether the account is allowed to sign in remotely.';

  @override
  String get errorNoCredentials =>
      'The remote PC requires a user name and password.';

  @override
  String get errorSessionStart =>
      'The remote desktop engine could not start the session.';

  @override
  String get errorInternal =>
      'The remote desktop engine hit an internal error and the session cannot continue.';

  @override
  String get errorAlreadyRunning => 'A session is already running.';

  @override
  String get errorEngineUnavailable =>
      'The remote desktop engine is unavailable; its native component may not have loaded.';

  @override
  String get errorEngineDisposed => 'The session has ended.';
}
