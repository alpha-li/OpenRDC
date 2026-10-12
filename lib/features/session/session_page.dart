/// The in-session view: the remote desktop plus the floating connection bar.
///
/// The bar follows the Windows App: a small pill floating at the top centre
/// rather than a docked title bar, which can be pinned in place or left to
/// auto-hide until the pointer reaches the top edge.
///
/// Its window controls -- full screen, restore, minimise -- are the native
/// bridge's, not a Flutter window package's: the borderless full screen a
/// session wants is not something the framework can produce, and while the
/// desktop fills the screen the bar is the only chrome there is.
library;

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/storage_paths.dart';
import '../../data/thumbnail_store.dart';
import '../../l10n/engine_labels.dart';
import '../../l10n/error_messages.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../engine/rdc_engine.dart';
import '../../models/pc_connection.dart';
import '../../theme/fluent_colors.dart';
import 'certificate_prompt.dart';
import 'desktop_surface.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({
    super.key,
    required this.connection,
    this.username = '',
    this.password = '',
    this.domain = '',
    this.ignoreCertificate = false,
    this.gateway,
    this.engine,
    this.thumbnails,
    this.onClose,
  });

  final PcConnection connection;

  /// Resolved by the caller from the saved credential, or collected from the
  /// user when the connection asks every time. Never persisted here: the
  /// connection record only holds a reference to a credential, not its secret.
  final String username;
  final String password;
  final String domain;

  /// Skips the certificate prompt for this connection. Off by default: the
  /// prompt is the only thing standing between the user and a silently
  /// intercepted session, so opting out has to be deliberate.
  final bool ignoreCertificate;

  /// Resolved by the caller, which is the only layer that can reach the store
  /// and the credential vault.
  final RdcGatewayRequest? gateway;

  /// Injectable for tests; otherwise a platform engine is created.
  final RdcEngine? engine;

  /// Where the session preview is written for the card grid. Injectable for the
  /// same reason as [engine]: a test points it at a temporary directory.
  final ThumbnailStore? thumbnails;

  /// How to leave when there is no page underneath to return to.
  ///
  /// Null means there is one: the connection centre pushed this page, so
  /// leaving is a pop. The `--connect` launch makes this page the application's
  /// root instead, where a pop would leave the navigator empty; that caller
  /// passes a callback that ends the process.
  final VoidCallback? onClose;

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  late final RdcEngine _engine = widget.engine ?? RdcEngine.create();
  late final bool _ownsEngine = widget.engine == null;
  late final ThumbnailStore _thumbnails =
      widget.thumbnails ??
      ThumbnailStore(StoragePaths.defaultForPlatform());
  final List<StreamSubscription<RdcEngineEvent>> _subscriptions = [];

  RdcSessionStatus _status = RdcSessionStatus.idle;
  RdcDesktopSize? _desktopSize;

  /// The remote machine's pointer, as last reported. Handed to the surface,
  /// which draws it: Flutter cannot be asked to use a picture as a cursor.
  RdcCursorShape? _cursor;

  /// The last failure. Either a bridge error code with the engine's own
  /// description, or a local engine state with no code at all -- the two are
  /// different kinds of thing and are worded in different tables.
  RdcSessionFailure? _error;

  /// Whether this attempt has reported CONNECTING yet.
  ///
  /// A status left over from the session a reconnect has already replaced
  /// arrives after the new attempt starts, and would otherwise read as the new
  /// one ending. Reconnecting clears this, so only a CONNECTING belonging to the
  /// current attempt re-arms the exit below.
  bool _seenConnecting = false;

  /// Whether the page has already decided to leave. A disconnect and a terminal
  /// status can both arrive for the same session, and a dialog can be waiting on
  /// top of the page; this is what keeps the departure to one.
  bool _leaving = false;

  /// Whether the user answered the certificate prompt with a refusal.
  ///
  /// The session ends just as it does for any other failure, but the user made
  /// this happen on purpose and knows why, so there is nothing to announce.
  bool _certificateDeclined = false;

  bool _barPinned = false;
  bool _barRevealed = false;
  Timer? _hideTimer;

  /// Guards against stacking certificate dialogs when a reconnect raises a
  /// second prompt before the first has been answered.
  bool _certificatePromptOpen = false;

  /// Takes the stored session preview, a little after the desktop comes up.
  ///
  /// Not immediately: at the moment the connection is up the host is usually
  /// still painting the desktop that has just been restored, and a preview of a
  /// half-drawn screen is worse than none.
  Timer? _thumbnailTimer;
  int _thumbnailAttempts = 0;

  /// How long after connecting the preview is taken, and how many times it is
  /// retried if the session has not drawn anything by then.
  static const Duration _thumbnailDelay = Duration(seconds: 5);
  static const int _thumbnailAttemptsLimit = 3;

  /// Polls the local clipboard. Flutter offers no change notification, so this
  /// is the only way to notice a copy happening elsewhere on the desktop.
  Timer? _clipboardTimer;

  /// The value last pushed to or pulled from the remote machine, so the poll
  /// does not re-announce what it just received and bounce the text back.
  String? _lastClipboardText;

  /// Guards the "start session in full screen" setting so a reconnect does not
  /// re-enter full screen after the user has deliberately left it.
  bool _enteredFullScreen = false;

  /// Debounces window resizes. A drag produces a continuous stream of sizes,
  /// and asking the host to change resolution for each one would flood the
  /// channel and make the desktop lurch about.
  Timer? _resizeTimer;

  /// The last resolution asked for, so a size that has already been applied is
  /// not requested again.
  (int, int)? _requestedDesktopSize;

  /// How long the bar lingers after the pointer leaves, when unpinned.
  static const Duration _autoHideDelay = Duration(seconds: 3);

  /// Distance from the top edge that reveals the bar, matching the app's
  /// "move the pointer to the top of the screen" behaviour.
  static const double _revealHotZone = 40;

  @override
  void initState() {
    super.initState();
    _barPinned = false;
    _subscriptions.add(_engine.events.listen(_onEvent));
    _startSession();

    // Flutter has no clipboard-change notification, so the local clipboard is
    // polled. Fast enough to feel immediate, slow enough not to matter.
    _clipboardTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _pollLocalClipboard(),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clipboardTimer?.cancel();
    _thumbnailTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    // Leaving the page without having gone through a status change -- the user
    // closing the tab, or the page being rebuilt away -- still has to give the
    // keyboard back, because the capture holds the local input method detached.
    _engine.setKeyboardCapture(false);
    // And it has to give the window back with it. Full screen here is a window
    // with no title bar, no border and no controls at all: left in place, the
    // connection centre the user lands on would be framed by something they
    // cannot resize, move or even close. A no-op when the window is ordinary.
    _engine.runWindowCommand(RdcWindowCommand.leaveFullScreen);
    if (_ownsEngine) {
      _engine.dispose();
    }
    super.dispose();
  }

  void _onEvent(RdcEngineEvent event) {
    if (!mounted) {
      return;
    }

    // Handled outside setState because it opens a route rather than changing
    // this page's state.
    if (event is RdcCertificateEvent) {
      _promptForCertificate(event.certificate);
      return;
    }
    // Likewise this talks to the platform rather than to this page's state.
    if (event is RdcClipboardEvent) {
      _onRemoteClipboardText(event.text);
      return;
    }

    // Decided inside the switch, acted on outside it: leaving opens or closes
    // routes, which is not state this page owns.
    var leaving = false;
    setState(() {
      switch (event) {
        case RdcCertificateEvent():
        case RdcClipboardEvent():
          // Unreachable: handled above. Listed so the switch stays exhaustive.
          break;
        case RdcStatusEvent(:final status):
          _status = status;
          if (status == RdcSessionStatus.connecting) {
            _seenConnecting = true;
          }
          // The session owns the keyboard while it is up, and gives it back the
          // moment it is not: the capture suspends the local input method, and a
          // window left without one cannot be typed into in Chinese at all.
          // This runs on every status change, which is what makes the release
          // impossible to miss -- disconnecting is a status change too.
          _engine.setKeyboardCapture(status == RdcSessionStatus.connected);
          // The card grid gets a picture of what the session looked like, taken
          // once the desktop has had a moment to finish painting.
          if (status == RdcSessionStatus.connected) {
            _scheduleThumbnail();
          }
          // Enter full screen once the session is actually up, rather than at
          // launch: doing it earlier would hide the connecting state, and a
          // failed connection would leave the user staring at a blank screen
          // with no window chrome to get out with.
          if (status == RdcSessionStatus.connected &&
              widget.connection.display.startFullScreen &&
              !_enteredFullScreen) {
            _enteredFullScreen = true;
            _engine.runWindowCommand(RdcWindowCommand.enterFullScreen);
          }
          // A terminal status means the session is over and will not resume on
          // its own: the engine's automatic reconnect runs inside FreeRDP and
          // re-reports CONNECTED without ever reporting DISCONNECTED on the way,
          // so reaching one of these really is the end. Staying would strand the
          // user on a dead window whose only exit is the bar's disconnect
          // button, which is what the connection centre is for instead.
          //
          // `_seenConnecting` is what keeps a status left over from the session
          // a reconnect has already replaced from reading as this one ending;
          // `isTerminal` is deliberately not used, because it counts idle.
          if ((status == RdcSessionStatus.disconnected ||
                  status == RdcSessionStatus.failed) &&
              _seenConnecting &&
              !_leaving) {
            leaving = true;
          }
        case RdcDesktopSizeEvent(:final size):
          _desktopSize = size;
        case RdcCursorEvent(:final cursor):
          _cursor = cursor;
        case RdcErrorEvent(:final code, :final message):
          // The engine's description is kept as the fallback rather than thrown
          // away: it is English and developer-facing, but for a failure the
          // message table does not know, showing it beats showing nothing.
          _error = (code: code, detail: message, engineError: null);
      }
    });

    if (leaving) {
      _leaveWithFailure();
    }
  }

  /// Puts text received from the remote machine onto the local clipboard.
  ///
  /// The value is recorded as the last one seen so the poll below does not
  /// immediately announce it back, which would echo the text across and, if the
  /// remote end did the same, loop indefinitely.
  Future<void> _onRemoteClipboardText(String text) async {
    if (!_clipboardAllows(remoteToLocal: true)) {
      return;
    }
    _lastClipboardText = text;
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Whether the connection's clipboard settings permit this direction.
  bool _clipboardAllows({required bool remoteToLocal}) {
    final mode = widget.connection.redirection.clipboardMode;
    return remoteToLocal ? mode.allowsRemoteToLocal : mode.allowsLocalToRemote;
  }

  /// Announces local clipboard changes to the remote machine.
  Future<void> _pollLocalClipboard() async {
    if (!_clipboardAllows(remoteToLocal: false) ||
        _status != RdcSessionStatus.connected) {
      return;
    }
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty || text == _lastClipboardText) {
        return;
      }
      _lastClipboardText = text;
      _engine.setLocalClipboardText(text);
    } on Object {
      // A clipboard read can fail when another application holds it open. That
      // is normal and transient; the next tick will pick the value up.
    }
  }

  /// Asks about a certificate and unblocks the session thread with the answer.
  ///
  /// The native side is waiting on this, and gives up after a minute, so every
  /// exit path has to answer — including the one where the page is torn down
  /// while the dialog is open.
  Future<void> _promptForCertificate(RdcCertificate certificate) async {
    if (_certificatePromptOpen) {
      // A reconnect can raise a second prompt before the first is answered.
      // Stacking dialogs would be unusable, so the extra one is refused; the
      // user will be asked again on the next attempt.
      _engine.respondToCertificate(RdcCertificateDecision.reject);
      return;
    }

    _certificatePromptOpen = true;
    try {
      int decision;
      try {
        decision = await showCertificatePrompt(context, certificate);
      } on Object {
        decision = RdcCertificateDecision.reject;
      }
      // Recorded before answering: the refusal fails the connect, and the
      // terminal status that follows is what sends the page home. Without this
      // the exit would report a security failure the user chose themselves.
      _certificateDeclined = decision == RdcCertificateDecision.reject;
      _engine.respondToCertificate(decision);
    } finally {
      _certificatePromptOpen = false;
    }
  }

  /// The sentence to show for the current failure, or the engine-unavailable
  /// wording when there is nothing to describe.
  ///
  /// One place rather than two: the toast and the full-window placeholder show
  /// the same failure, and wording them separately is how they drift apart.
  String _errorText(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = _error;
    if (error == null) {
      return l10n.sessionEngineUnavailable;
    }
    // The wording lives with the connection centre's, which reports these same
    // failures once this page is gone -- one table, so the two cannot drift.
    return rdcSessionFailureMessage(l10n, error);
  }

  void _startSession() {
    // A refusal belongs to the attempt whose prompt raised it; the next attempt
    // answers for itself.
    _certificateDeclined = false;
    final connection = widget.connection;
    try {
      _engine.connect(
        RdcConnectionRequest(
          hostname: connection.effectiveHostname,
          port: connection.effectivePort,
          username: widget.username,
          password: widget.password,
          domain: widget.domain,
          desktopWidth: connection.display.resolution.width,
          desktopHeight: connection.display.resolution.height,
          colorDepth: connection.display.colorDepth,
          adminSession: connection.adminSession,
          reconnectIfDropped: connection.reconnectIfDropped,
          audioPlayback: switch (connection.redirection.audioPlayback) {
            AudioPlaybackMode.onThisComputer => RdcAudioPlayback.onThisComputer,
            AudioPlaybackMode.onRemotePc => RdcAudioPlayback.onRemote,
            AudioPlaybackMode.never => RdcAudioPlayback.never,
          },
          useMultiMonitor:
              connection.display.displayMode == DisplayMode.allDisplays,
          gateway: widget.gateway,
          ignoreCertificate: widget.ignoreCertificate,
          folders: [
            for (final folder in connection.redirection.folders)
              RdcRedirectedFolder(path: folder.path, name: folder.shareName),
          ],
          redirectAllDrives: connection.redirection.redirectDrives,
        ),
      );
    } on RdcEngineException catch (error) {
      setState(
        () => _error = (
          code: 0,
          detail: error.detail ?? '',
          engineError: error.kind,
        ),
      );
    } on Object catch (error) {
      // Not an engine failure at all: something in the Dart layer threw, so
      // there is no category to look up and the text is all there is.
      setState(() => _error = (code: 0, detail: '$error', engineError: null));
    }
  }

  void _disconnect() {
    if (mounted) {
      // Nothing to report: the user asked to stop, so they get no explanation.
      _leave();
    }
  }

  /// Leaves because the session failed, handing the reason to the caller.
  void _leaveWithFailure() {
    // A refusal is the user's own doing and needs no announcing.
    _leave(_certificateDeclined ? null : _error);
  }

  /// Takes this page off the screen, handing [failure] to whoever pushed it.
  ///
  /// One exit for every way out, so the question of which route to take is
  /// answered in one place. A null [failure] means the departure needs no
  /// explanation.
  void _leave([RdcSessionFailure? failure]) {
    if (_leaving) {
      return;
    }
    _leaving = true;

    // Asked for even when the session ended by itself, and before the page goes
    // anywhere: the native side has one session per process and cannot begin
    // another until the finished one has been reaped, and reaping is what this
    // does. The status that brought the page here says the session has stopped
    // being useful, not that its thread is gone.
    _engine.stop();

    final route = ModalRoute.of(context);
    if (route == null || route.isFirst) {
      // The `--connect` launch: this page is the application's root, so there is
      // no connection centre underneath to go back to. `canPop` is not the test
      // here -- it reports true while a dialog is up, which would pop the only
      // route there is and leave an empty navigator behind it.
      widget.onClose?.call();
      return;
    }

    // The certificate prompt is pushed on this same navigator, above the page,
    // so a bare pop would take the dialog instead -- and with `_leaving` already
    // set, the page would then be stranded on a session that is over. Clear
    // whatever is above first; this is a no-op when the page is already topmost.
    final navigator = Navigator.of(context);
    navigator.popUntil((candidate) => candidate == route);
    navigator.pop<RdcSessionFailure?>(failure);
  }

  void _reconnect() {
    _engine.stop();
    setState(() {
      _error = null;
      _status = RdcSessionStatus.idle;
      // From here on, statuses belong to the new attempt. Without this, the
      // DISCONNECTED still on its way from the session just stopped would read
      // as this attempt having failed before it ever reported connecting.
      _seenConnecting = false;
    });
    _startSession();
  }

  /// Keeps the bar in step with where the pointer is.
  ///
  /// Fed by every position the pointer reports, not only the ones Flutter calls
  /// hovers: a movement with a button held arrives as a move, and the bar has to
  /// follow the pointer just the same.
  void _onPointerActivity(Offset localPosition) {
    // Only the pinned state suppresses auto-hide. An earlier version also
    // tested the connection's "start in full screen" setting here, which is a
    // static preference rather than a runtime state -- with it set, the bar
    // could never be revealed at all, leaving a full-screen session with no
    // visible controls and no way out but the keyboard.
    if (_barPinned) {
      return;
    }

    if (localPosition.dy <= _revealHotZone) {
      if (!_barRevealed) {
        setState(() => _barRevealed = true);
      }
      // Back inside the hot zone, any countdown from a previous visit is moot:
      // left running it would hide the bar from under the pointer.
      _hideTimer?.cancel();
    } else {
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_barPinned || !_barRevealed) {
      return;
    }
    _hideTimer = Timer(_autoHideDelay, () {
      if (mounted) {
        setState(() => _barRevealed = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textureId = _engine.textureId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Reported from build rather than from a listener because the size is
          // only known once the frame has been laid out; the debounce inside
          // keeps that from turning into work on every frame.
          _scheduleResize(
            Size(constraints.maxWidth, constraints.maxHeight),
            MediaQuery.devicePixelRatioOf(context),
          );
          // Every way the pointer can move has to be heard, not just the one
          // that reports itself as a hover: Flutter sends a movement with a
          // button held as a move instead, and a bar that only listens for
          // hovers stays up for the rest of the session the moment the pointer
          // is dragged away from it.
          return MouseRegion(
            onHover: (event) => _onPointerActivity(event.localPosition),
            // Leaving the window has to undo the reveal as well. There is no
            // further position to react to out there, so nothing else will.
            onExit: (_) => _scheduleHide(),
            child: Listener(
              onPointerMove: (event) => _onPointerActivity(event.localPosition),
              child: _buildSessionStack(textureId),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionStack(int textureId) {
    return Stack(
      children: [
        Positioned.fill(
          child: _engine.isAvailable
              ? DesktopSurface(
                  engine: _engine,
                  textureId: textureId,
                  desktopSize: _desktopSize,
                  cursor: _cursor,
                  swapMouseButtons: widget.connection.swapMouseButtons,
                  fitToWindow: widget.connection.display.fitSessionToWindow,
                  onLocalShortcut: _onLocalShortcut,
                )
              : _UnavailableView(error: _errorText(context)),
        ),
        if (_status == RdcSessionStatus.connecting ||
            _status == RdcSessionStatus.authenticating)
          Positioned.fill(child: _ConnectingOverlay(status: _status)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Align(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              offset: (_barPinned || _barRevealed)
                  ? Offset.zero
                  : const Offset(0, -1.5),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: (_barPinned || _barRevealed) ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ConnectionBar(
                    name: widget.connection.displayName,
                    status: _status,
                    fullScreen: _engine.isFullScreen,
                    pinned: _barPinned,
                    onTogglePin: () => setState(() {
                      _barPinned = !_barPinned;
                      if (_barPinned) {
                        _hideTimer?.cancel();
                        _barRevealed = true;
                      } else {
                        _scheduleHide();
                      }
                    }),
                    onDisconnect: _disconnect,
                    onReconnect: _reconnect,
                    onSendCtrlAltDel: _sendCtrlAltDel,
                    onToggleFullScreen: _toggleFullScreen,
                    onRestore: _restoreWindow,
                    onMinimize: () =>
                        _engine.runWindowCommand(RdcWindowCommand.minimize),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_error != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _ErrorToast(message: _errorText(context)),
          ),
      ],
    );
  }

  /// Asks the host to match a new window size, if the connection wants that.
  ///
  /// Sizes are in device pixels, not logical ones: the point of following the
  /// window is that one remote pixel lands on one local pixel, and on a scaled
  /// display those differ by the device pixel ratio.
  void _scheduleResize(Size logicalSize, double devicePixelRatio) {
    if (!widget.connection.display.updateResolutionOnResize) {
      return;
    }

    final width = (logicalSize.width * devicePixelRatio).round();
    final height = (logicalSize.height * devicePixelRatio).round();
    if (width <= 0 || height <= 0) {
      return;
    }
    // Already asked for this, or already there.
    if (_requestedDesktopSize == (width, height)) {
      return;
    }

    _resizeTimer?.cancel();
    _resizeTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _status != RdcSessionStatus.connected) {
        return;
      }
      _requestedDesktopSize = (width, height);
      _engine.resizeDesktop(width, height);
    });
  }

  /// Handles the client's own keyboard shortcuts.
  ///
  /// Returns true for anything it acted on, which stops the key being forwarded
  /// to the remote machine.
  bool _onLocalShortcut(RemoteShortcut shortcut) {
    switch (shortcut) {
      case RemoteShortcut.connectionBar:
        setState(() => _barRevealed = true);
        _scheduleHide();
        return true;
      case RemoteShortcut.fullScreen:
        _toggleFullScreen();
        return true;
    }
  }

  void _toggleFullScreen() {
    _applyWindowCommand(RdcWindowCommand.toggleFullScreen);
  }

  /// Puts the window back to the size it had before it went full screen.
  ///
  /// A separate command from [_toggleFullScreen] even though both end up
  /// leaving full screen: this is the one the bar offers while the desktop
  /// fills the screen, where there is no title bar left to restore the window
  /// with, and it reads as "give me my window back" rather than "switch the
  /// other way".
  void _restoreWindow() {
    _applyWindowCommand(RdcWindowCommand.restore);
  }

  /// Starts the countdown to the session preview.
  void _scheduleThumbnail() {
    _thumbnailTimer?.cancel();
    _thumbnailAttempts = 0;
    _thumbnailTimer = Timer(_thumbnailDelay, _captureThumbnail);
  }

  /// Takes a frame of the session for the card grid, retrying while there is
  /// nothing to take: a session can report itself connected before it has drawn
  /// anything, and the first paint is exactly what the preview is for.
  Future<void> _captureThumbnail() async {
    final frame = _engine.captureFrame();
    if (frame == null) {
      if (++_thumbnailAttempts < _thumbnailAttemptsLimit) {
        _thumbnailTimer = Timer(_thumbnailDelay, _captureThumbnail);
      }
      return;
    }
    await _thumbnails.save(widget.connection.id, frame);
  }

  /// Sends a window command and keeps the bar in step with what it did.
  ///
  /// The bar is pinned on the way out of full screen, because leaving the
  /// session with no chrome and no visible affordance is a dead end.
  void _applyWindowCommand(int command) {
    _engine.runWindowCommand(command);
    if (!mounted) {
      return;
    }
    setState(() {
      _barRevealed = true;
      _barPinned = !_engine.isFullScreen;
    });
    if (!_barPinned) {
      _scheduleHide();
    }
  }

  void _sendCtrlAltDel() {
    // Synthesised natively from scancodes, because the local OS swallows the
    // real key combination before it ever reaches the window.
    _engine.sendCtrlAltDel();
  }
}

class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            FluentIcons.warning_24_regular,
            size: 32,
            color: Colors.white54,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectingOverlay extends StatelessWidget {
  const _ConnectingOverlay({required this.status});

  final RdcSessionStatus status;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              status.label(AppLocalizations.of(context)),
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// The floating session toolbar.
///
/// Only the controls attested for the current Windows App are included — pin,
/// session name, connection quality and the overflow menu. Anything beyond that
/// would be invention, so it waits until it can be verified or is genuinely
/// needed.
class _ConnectionBar extends StatelessWidget {
  const _ConnectionBar({
    required this.name,
    required this.status,
    required this.fullScreen,
    required this.pinned,
    required this.onTogglePin,
    required this.onDisconnect,
    required this.onReconnect,
    required this.onSendCtrlAltDel,
    required this.onToggleFullScreen,
    required this.onRestore,
    required this.onMinimize,
  });

  final String name;
  final RdcSessionStatus status;

  /// Whether the window is currently filling the screen, which is what decides
  /// between offering full screen and offering to undo it.
  final bool fullScreen;

  final bool pinned;
  final VoidCallback onTogglePin;
  final VoidCallback onDisconnect;
  final VoidCallback onReconnect;
  final VoidCallback onSendCtrlAltDel;
  final VoidCallback onToggleFullScreen;
  final VoidCallback onRestore;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final connected = status == RdcSessionStatus.connected;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: 40,
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          // The bar floats over arbitrary desktop content, so it uses the
          // acrylic-style translucent layer rather than a solid surface.
          color: colors.solidBackgroundFillColorTertiary.withValues(
            alpha: 0.92,
          ),
          border: Border.all(color: colors.surfaceStrokeColorDefault),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BarIconButton(
              icon: pinned
                  ? FluentIcons.pin_24_filled
                  : FluentIcons.pin_24_regular,
              tooltip: pinned
                  ? AppLocalizations.of(context).sessionUnpinBar
                  : AppLocalizations.of(context).sessionPinBar,
              active: pinned,
              onPressed: onTogglePin,
            ),
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected
                    ? colors.systemFillColorSuccess
                    : colors.systemFillColorCaution,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textFillColorPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // While the session fills the screen the title bar is gone, so the
            // bar carries the way back: the same slot means full screen when
            // there is a window to expand and restore when there is not.
            if (fullScreen)
              _BarIconButton(
                icon: FluentIcons.full_screen_minimize_24_regular,
                tooltip: AppLocalizations.of(context).sessionRestoreWindow,
                onPressed: onRestore,
              )
            else
              _BarIconButton(
                icon: FluentIcons.full_screen_maximize_24_regular,
                tooltip: AppLocalizations.of(context).sessionFullScreen,
                onPressed: onToggleFullScreen,
              ),
            _BarIconButton(
              icon: FluentIcons.subtract_24_regular,
              tooltip: AppLocalizations.of(context).sessionMinimize,
              onPressed: onMinimize,
            ),
            const SizedBox(width: 4),
            PopupMenuButton<int>(
              tooltip: AppLocalizations.of(context).sessionOptions,
              icon: Icon(
                FluentIcons.more_horizontal_24_regular,
                size: 16,
                color: colors.textFillColorSecondary,
              ),
              splashRadius: 16,
              padding: EdgeInsets.zero,
              onSelected: (index) => switch (index) {
                0 => onSendCtrlAltDel(),
                1 => onReconnect(),
                _ => onDisconnect(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  height: 36,
                  value: 0,
                  child: Text(AppLocalizations.of(context).sessionSendCad),
                ),
                PopupMenuItem(
                  height: 36,
                  value: 1,
                  child: Text(AppLocalizations.of(context).sessionReconnect),
                ),
                PopupMenuItem(
                  height: 36,
                  value: 2,
                  child: Text(AppLocalizations.of(context).sessionDisconnect),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        color: active
            ? colors.accentFillColorDefault
            : colors.textFillColorSecondary,
        splashRadius: 16,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _ErrorToast extends StatelessWidget {
  const _ErrorToast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.solidBackgroundFillColorTertiary,
        border: Border.all(color: colors.systemFillColorCritical),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.warning_24_regular,
            size: 16,
            color: colors.systemFillColorCritical,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: colors.textFillColorPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
