import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openrdc/data/storage_paths.dart';
import 'package:openrdc/data/thumbnail_store.dart';
import 'package:openrdc/engine/rdc_engine.dart';
import 'package:openrdc/features/session/desktop_surface.dart';
import 'package:openrdc/features/session/session_page.dart';
import 'package:openrdc/models/pc_connection.dart';
import 'package:rdc_bridge/rdc_bridge.dart' as bridge;

import '../support/test_app.dart';

void main() {
  late _FakeEngine engine;

  setUp(() => engine = _FakeEngine());
  tearDown(() => engine.dispose());

  /// The connection bar, which is hidden until the pointer reaches the top of
  /// the window, is the only way to the window controls while the session fills
  /// the screen -- there is no title bar left to click.
  Future<void> revealBar(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    final size = tester.getSize(find.byType(SessionPage));
    await mouse.moveTo(Offset(size.width / 2, 8));
    await tester.pump();
    // Let the bar finish sliding into view, so the buttons can be tapped.
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpSession(
    WidgetTester tester, {
    ThumbnailStore? thumbnails,
  }) async {
    await tester.pumpWidget(
      testApp(
        home: SessionPage(
          connection: PcConnection(
            id: 'pc',
            hostname: 'pc.example.com',
            // Off so a layout-triggered resize debounce does not outlive the
            // test; the window commands are what this file is about.
            display: const PcDisplaySettings(updateResolutionOnResize: false),
          ),
          engine: engine,
          thumbnails: thumbnails,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a windowed session is offered full screen', (tester) async {
    await pumpSession(tester);
    await revealBar(tester);

    expect(
      find.byIcon(FluentIcons.full_screen_maximize_24_regular),
      findsOneWidget,
    );
    expect(
      find.byIcon(FluentIcons.full_screen_minimize_24_regular),
      findsNothing,
    );
  });

  testWidgets('a full-screen session is offered restore instead', (
    tester,
  ) async {
    engine.fullScreen = true;
    await pumpSession(tester);
    await revealBar(tester);

    expect(
      find.byIcon(FluentIcons.full_screen_minimize_24_regular),
      findsOneWidget,
    );
    expect(
      find.byIcon(FluentIcons.full_screen_maximize_24_regular),
      findsNothing,
    );
  });

  testWidgets('restoring asks the engine for the window back', (tester) async {
    engine.fullScreen = true;
    await pumpSession(tester);
    await revealBar(tester);

    await tester.tap(find.byIcon(FluentIcons.full_screen_minimize_24_regular));
    await tester.pump();

    // The restore command, not the full-screen toggle: the two would both end
    // up leaving full screen, but only one of them is what the user asked for,
    // and the native side treats them differently.
    expect(engine.windowCommands, [RdcWindowCommand.restore]);

    // And the bar follows the window back: with the title bar returned, the
    // slot offers full screen again.
    expect(
      find.byIcon(FluentIcons.full_screen_maximize_24_regular),
      findsOneWidget,
    );
  });

  // The capture suspends the local input method, so a session that ends without
  // giving it back leaves the rest of the application untypable in Chinese.
  // Both ways out are checked, because the page can be left either way: the
  // connection dropping while it stays up, or the page itself going away.
  testWidgets('a connected session takes the keyboard, a dropped one gives it '
      'back', (tester) async {
    await pumpSession(tester);
    expect(engine.keyboardCapture, isFalse);

    engine.emit(const RdcStatusEvent(RdcSessionStatus.connected));
    await tester.pump();
    expect(engine.keyboardCapture, isTrue);

    engine.emit(const RdcStatusEvent(RdcSessionStatus.disconnected));
    await tester.pump();
    expect(engine.keyboardCapture, isFalse);
  });

  testWidgets('leaving the page gives the keyboard back', (tester) async {
    await pumpSession(tester);
    engine.emit(const RdcStatusEvent(RdcSessionStatus.connected));
    await tester.pump();
    expect(engine.keyboardCapture, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(engine.keyboardCapture, isFalse);
  });

  // Disconnecting from full screen lands the user back on the connection centre,
  // which would otherwise be showing inside a window with no title bar, no border
  // and nothing to resize or close it with.
  testWidgets('leaving the page gives the window back too', (tester) async {
    engine.fullScreen = true;
    await pumpSession(tester);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(engine.windowCommands, contains(RdcWindowCommand.leaveFullScreen));
    expect(engine.fullScreen, isFalse);
  });

  /// Delivers an engine event and lets the page rebuild for it: a stream event
  /// arrives on a microtask, and the frame it dirties is the one after that.
  Future<void> emitEvent(WidgetTester tester, RdcEngineEvent event) async {
    engine.emit(event);
    await tester.pump();
    await tester.pump();
  }

  /// Puts the mouse over the middle of the desktop, without pressing anything.
  Future<void> hoverDesktop(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(DesktopSurface)));
    await tester.pump();
  }

  MouseCursor desktopCursor(WidgetTester tester) => tester
      .widget<MouseRegion>(
        find.descendant(
          of: find.byType(DesktopSurface),
          matching: find.byType(MouseRegion),
        ),
      )
      .cursor;

  // The host's pointer has to follow the local one even when no button is held:
  // otherwise the remote machine only learns where the pointer is when it is
  // clicked, and hovering over a remote menu or link does nothing.
  testWidgets('a buttonless move carries the pointer to the session', (
    tester,
  ) async {
    await pumpSession(tester);
    // Without a reported size there are no desktop coordinates to map to, and
    // the surface sends nothing at all.
    await emitEvent(
      tester,
      const RdcDesktopSizeEvent(RdcDesktopSize(1280, 720)),
    );
    engine.mouseActions.clear();

    await hoverDesktop(tester);

    expect(engine.mouseActions, contains(RdcMouseAction.move));
  });

  /// How visible the connection bar is: 1 while it is showing, 0 once it has
  /// hidden itself again.
  double barOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byIcon(FluentIcons.pin_24_regular),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  /// A mouse inside the window, at the top edge and then somewhere else.
  Future<TestGesture> mouseAtTop(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(400, 8));
    await tester.pump(const Duration(milliseconds: 300));
    return mouse;
  }

  testWidgets('the bar hides itself once the pointer leaves the top', (
    tester,
  ) async {
    await pumpSession(tester);
    expect(barOpacity(tester), 0);

    final mouse = await mouseAtTop(tester);
    expect(barOpacity(tester), 1);

    // Away from it again, over the desktop. Nothing else is going to hide the
    // bar: if the event that says "the pointer has left" does not arrive, the
    // bar sits there for the rest of the session.
    await mouse.moveTo(const Offset(400, 400));
    await tester.pump(const Duration(seconds: 4));
    expect(barOpacity(tester), 0);
  });

  // Flutter reports a movement with a button held as a move rather than a
  // hover, so a bar watching only hovers would be stuck up the first time the
  // pointer is dragged away from it.
  testWidgets('the bar hides itself when the pointer is dragged away', (
    tester,
  ) async {
    await pumpSession(tester);
    final mouse = await mouseAtTop(tester);
    expect(barOpacity(tester), 1);

    await mouse.down(const Offset(400, 8));
    await mouse.moveTo(const Offset(400, 400));
    await tester.pump(const Duration(seconds: 4));

    expect(barOpacity(tester), 0);
  });

  // Out of the window there is no further position to react to, which is
  // exactly why leaving has to undo the reveal itself.
  testWidgets('the bar hides itself when the pointer leaves the window', (
    tester,
  ) async {
    await pumpSession(tester);
    final mouse = await mouseAtTop(tester);
    expect(barOpacity(tester), 1);

    await mouse.moveTo(const Offset(2000, 2000));
    await tester.pump(const Duration(seconds: 4));

    expect(barOpacity(tester), 0);
  });

  testWidgets('a countdown from an earlier visit does not hide the bar under '
      'the pointer', (tester) async {
    await pumpSession(tester);
    final mouse = await mouseAtTop(tester);

    // Away, which starts the countdown, and back before it runs out.
    await mouse.moveTo(const Offset(400, 400));
    await tester.pump(const Duration(seconds: 1));
    await mouse.moveTo(const Offset(400, 8));
    await tester.pump(const Duration(seconds: 4));

    expect(barOpacity(tester), 1);
  });

  testWidgets('a hidden remote pointer hides the local one', (tester) async {
    await pumpSession(tester);
    expect(desktopCursor(tester), SystemMouseCursors.basic);

    await emitEvent(
      tester,
      const RdcCursorEvent(RdcCursorShape(kind: RdcCursorKind.hidden)),
    );
    expect(desktopCursor(tester), SystemMouseCursors.none);

    await emitEvent(
      tester,
      const RdcCursorEvent(RdcCursorShape(kind: RdcCursorKind.defaultArrow)),
    );
    expect(desktopCursor(tester), SystemMouseCursors.basic);
  });

  /// A frame of [width] x [height], which is all the store needs to make a
  /// preview out of it.
  RdcFrame sessionFrame(int width, int height) => RdcFrame(
    width: width,
    height: height,
    pixels: Uint8List(width * height * 4)..fillRange(0, width * height * 4, 255),
  );

  /// A temporary home for the previews, thrown away with the test.
  Future<ThumbnailStore> temporaryThumbnails(WidgetTester tester) async {
    late Directory tempDir;
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp('openrdc_preview_test');
    });
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    return ThumbnailStore(StoragePaths.forDirectory(tempDir));
  }

  /// Runs the countdown out and then lets the work it started finish.
  ///
  /// The two halves need different clocks and have to take turns: the timer
  /// runs on the test's fake one, while decoding a frame and writing a file are
  /// real work that only progresses on the real event loop.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
  }

  testWidgets('a connected session leaves a preview for the card grid', (
    tester,
  ) async {
    final thumbnails = await temporaryThumbnails(tester);
    engine.frame = sessionFrame(8, 4);

    await pumpSession(tester, thumbnails: thumbnails);
    await emitEvent(tester, const RdcStatusEvent(RdcSessionStatus.connected));
    await settle(tester);

    expect(File(thumbnails.pathFor('pc')).existsSync(), isTrue);
  });

  // A session can report itself connected before the host has drawn anything,
  // and a preview of nothing is worse than none: the card would rather keep the
  // artwork it has than show a blank rectangle.
  testWidgets('the preview waits for the session to paint something', (
    tester,
  ) async {
    final thumbnails = await temporaryThumbnails(tester);
    engine.frame = null;

    await pumpSession(tester, thumbnails: thumbnails);
    await emitEvent(tester, const RdcStatusEvent(RdcSessionStatus.connected));
    await settle(tester);
    expect(File(thumbnails.pathFor('pc')).existsSync(), isFalse);

    engine.frame = sessionFrame(8, 4);
    await settle(tester);

    expect(File(thumbnails.pathFor('pc')).existsSync(), isTrue);
  });

  testWidgets('a picture from the host becomes the pointer', (tester) async {
    await pumpSession(tester);
    await hoverDesktop(tester);

    // A 2x2 image, opaque: red, green, blue, white.
    await emitEvent(
      tester,
      RdcCursorEvent(
        RdcCursorShape(
          kind: RdcCursorKind.image,
          width: 2,
          height: 2,
          hotspotX: 0,
          hotspotY: 0,
          pixels: Uint8List.fromList(const [
            255, 0, 0, 255, //
            0, 255, 0, 255, //
            0, 0, 255, 255, //
            255, 255, 255, 255, //
          ]),
        ),
      ),
    );

    // Decoding is real work on the engine's thread, which the fake clock a
    // widget test runs on does not advance by itself.
    await tester.runAsync(() async {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.byType(RawImage), findsOneWidget);
    expect(desktopCursor(tester), SystemMouseCursors.none);
  });

  /// Leaving a session that ended, rather than parking the user on it.
  ///
  /// Mounted as a pushed route -- the way the connection centre opens a session
  /// -- so the test can see what the page hands back on its way out. The
  /// `pumpSession` above mounts it as the root, where a pop does nothing at all.
  group('a session that ends', () {
    const certificate = RdcCertificate(
      host: 'pc.example.com',
      port: 3389,
      commonName: 'pc',
      subject: 'CN=pc',
      issuer: 'CN=pc',
      fingerprint: 'AA:BB:CC',
      changed: false,
      nameMismatch: false,
      oldFingerprint: '',
    );

    late List<RdcSessionFailure?> popped;

    PcConnection connection() => PcConnection(
      id: 'pc',
      hostname: 'pc.example.com',
      display: const PcDisplaySettings(updateResolutionOnResize: false),
    );

    /// Opens the session over a page that records what it returns.
    Future<void> pumpPushed(
      WidgetTester tester, {
      VoidCallback? onClose,
    }) async {
      popped = <RdcSessionFailure?>[];
      await tester.pumpWidget(
        testApp(
          home: Builder(
            builder: (context) => GestureDetector(
              onTap: () async {
                popped.add(
                  await Navigator.of(context).push<RdcSessionFailure>(
                    MaterialPageRoute(
                      builder: (_) => SessionPage(
                        connection: connection(),
                        engine: engine,
                        onClose: onClose,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    /// Lets a route change finish without waiting for animations to stop.
    ///
    /// `pumpAndSettle` is unusable while a session is coming up: the connecting
    /// overlay spins for as long as it is on screen, so there is never a frame
    /// with nothing left to do. Long enough for the page transitions either way.
    Future<void> advance(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// Opens the session as the application's root, the way `--connect` does.
    Future<void> pumpRoot(
      WidgetTester tester, {
      required VoidCallback onClose,
    }) async {
      await tester.pumpWidget(
        testApp(
          home: SessionPage(
            connection: connection(),
            engine: engine,
            onClose: onClose,
          ),
        ),
      );
      await tester.pump();
    }

    /// Picks an entry out of the connection bar's overflow menu.
    Future<void> choose(
      WidgetTester tester,
      IconData icon,
      String label,
    ) async {
      await revealBar(tester);
      await tester.tap(find.byIcon(icon));
      await advance(tester);
      await tester.tap(find.text(label));
      await advance(tester);
    }

    testWidgets('hands the failure back and returns to what opened it', (
      tester,
    ) async {
      await pumpPushed(tester);

      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.connecting),
      );
      await emitEvent(
        tester,
        const RdcErrorEvent(
          code: bridge.RdcResult.errConnectFailed,
          message: 'host unreachable',
        ),
      );
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.disconnected),
      );
      await advance(tester);

      expect(popped, hasLength(1));
      final failure = popped.single;
      expect(failure, isNotNull);
      expect(failure!.code, bridge.RdcResult.errConnectFailed);
      expect(failure.detail, 'host unreachable');
      expect(find.byType(SessionPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
      // Asking to stop is what reaps the finished session on the native side;
      // without it the next connection aborts the process rather than failing.
      expect(engine.stops, 1);
    });

    testWidgets('returns after a session that had been up goes down', (
      tester,
    ) async {
      await pumpPushed(tester);

      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.connecting),
      );
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.connected),
      );
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.disconnected),
      );
      await advance(tester);

      // Nothing was reported wrong, so there is nothing to announce.
      expect(popped, hasLength(1));
      expect(popped.single, isNull);
      expect(find.byType(SessionPage), findsNothing);
    });

    testWidgets('a disconnect the user asked for leaves once and in silence', (
      tester,
    ) async {
      await pumpPushed(tester);
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.connecting),
      );

      await choose(
        tester,
        FluentIcons.more_horizontal_24_regular,
        '断开连接',
      );

      expect(popped, hasLength(1));
      expect(popped.single, isNull);

      // The engine reports the session it has just stopped going down; that
      // must not read as a second departure.
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.disconnected),
      );
      await advance(tester);

      expect(popped, hasLength(1));
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a reconnect re-arms, and the stale disconnect is ignored', (
      tester,
    ) async {
      await pumpPushed(tester);
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.connecting),
      );
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.connected),
      );

      await choose(
        tester,
        FluentIcons.more_horizontal_24_regular,
        '重新连接',
      );

      // The session that was just stopped reports itself down. The attempt that
      // replaced it must not take that for its own failure.
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.disconnected),
      );
      await advance(tester);
      expect(popped, isEmpty);

      // Once the new attempt reports itself connecting, a failure is its own.
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.connecting),
      );
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.disconnected),
      );
      await advance(tester);

      expect(popped, hasLength(1));
    });

    testWidgets('a failure under the certificate prompt still leaves', (
      tester,
    ) async {
      await pumpPushed(tester);
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.connecting),
      );
      await emitEvent(tester, const RdcCertificateEvent(certificate));
      await advance(tester);

      expect(
        find.text('无法验证远程计算机的身份。是否仍要连接？'),
        findsOneWidget,
      );

      // The prompt times out or the connect fails behind it. Popping blindly
      // would take the dialog instead of the page and strand the session.
      await emitEvent(
        tester,
        const RdcErrorEvent(
          code: bridge.RdcResult.errConnectFailed,
          message: 'host unreachable',
        ),
      );
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.disconnected),
      );
      await advance(tester);

      expect(popped, hasLength(1));
      expect(popped.single!.code, bridge.RdcResult.errConnectFailed);
      expect(find.byType(SessionPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('declining the certificate returns with nothing to announce', (
      tester,
    ) async {
      await pumpPushed(tester);
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.connecting),
      );
      await emitEvent(tester, const RdcCertificateEvent(certificate));
      await advance(tester);

      await tester.tap(find.text('否'));
      await advance(tester);

      // Refusing fails the connect, exactly as an unreachable host does.
      await emitEvent(
        tester,
        const RdcErrorEvent(
          code: bridge.RdcResult.errTlsFailed,
          message: 'tls',
        ),
      );
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.disconnected),
      );
      await advance(tester);

      expect(popped, hasLength(1));
      expect(popped.single, isNull);
    });

    testWidgets('the --connect root closes instead of popping', (tester) async {
      var closes = 0;
      await pumpRoot(tester, onClose: () => closes++);

      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.connecting),
      );
      await emitEvent(
        tester,
        const RdcStatusEvent(RdcSessionStatus.disconnected),
      );
      await advance(tester);

      expect(closes, 1);
      // Nothing was popped: this page is the whole navigator.
      expect(find.byType(SessionPage), findsOneWidget);
      // Still asked to stop on the way out, even though the process is ending.
      expect(engine.stops, 1);
    });
  });
}

/// A stand-in for the native engine that records what the page asks of it.
///
/// [fullScreen] mirrors the real side, which flips its own state while handling
/// the command -- the page reads it back immediately afterwards, so a fake that
/// only recorded the call would not exercise the same path.
class _FakeEngine implements RdcEngine {
  final List<int> windowCommands = [];
  final StreamController<RdcEngineEvent> _events =
      StreamController<RdcEngineEvent>.broadcast();

  bool fullScreen = false;

  /// What the session has drawn, as [captureFrame] hands it over. Null stands
  /// for a session that has not painted anything yet.
  RdcFrame? frame;

  @override
  RdcFrame? captureFrame() => frame;

  /// Whether the session currently holds the keyboard. Null would mean the page
  /// never said either way, which is why it starts false rather than unset.
  bool keyboardCapture = false;

  /// Mouse actions sent to the session, in order.
  final List<int> mouseActions = [];

  /// Delivers an engine event to whoever is listening, the way the real engine
  /// does from its native threads.
  void emit(RdcEngineEvent event) => _events.add(event);

  @override
  void setKeyboardCapture(bool enabled) => keyboardCapture = enabled;

  @override
  void runWindowCommand(int command) {
    windowCommands.add(command);
    switch (command) {
      case RdcWindowCommand.toggleFullScreen:
        fullScreen = !fullScreen;
      case RdcWindowCommand.enterFullScreen:
        fullScreen = true;
      case RdcWindowCommand.restore:
      case RdcWindowCommand.leaveFullScreen:
        fullScreen = false;
    }
  }

  @override
  bool get isFullScreen => fullScreen;

  @override
  Stream<RdcEngineEvent> get events => _events.stream;

  @override
  bool get isAvailable => true;

  @override
  String get backendName => 'fake';

  @override
  int get textureId => -1;

  @override
  void connect(RdcConnectionRequest request) {}

  @override
  int startTestPattern({required int width, required int height}) => 0;

  /// How many times the page asked the session to stop.
  ///
  /// Leaving has to ask even for a session that has already ended on its own:
  /// the native side has one session per process and cannot begin another until
  /// the finished one has been reaped, and reaping is what `stop` does.
  int stops = 0;

  @override
  void stop() => stops++;

  @override
  void sendMouse(int action, int x, int y, {int wheelDelta = 0}) {
    mouseActions.add(action);
  }

  @override
  void sendKey({
    required int scancode,
    required bool down,
    bool extended = false,
  }) {}

  @override
  void sendText(String text) {}

  @override
  void sendCtrlAltDel() {}

  @override
  void respondToCertificate(int decision) {}

  @override
  void setLocalClipboardText(String text) {}

  @override
  void resizeDesktop(int width, int height) {}

  @override
  bool get isCredentialStorePersistent => false;

  @override
  Future<bool> storeCredential(String credentialId, String password) async =>
      false;

  @override
  Future<String?> loadCredential(String credentialId) async => null;

  @override
  Future<void> deleteCredential(String credentialId) async {}

  @override
  Future<void> dispose() async {
    if (!_events.isClosed) {
      await _events.close();
    }
  }
}
