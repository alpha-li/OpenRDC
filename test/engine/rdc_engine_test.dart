import 'package:flutter_test/flutter_test.dart';
import 'package:openrdc/engine/rdc_engine.dart';
import 'package:rdc_bridge/rdc_bridge.dart' as bridge;

void main() {
  group('RdcSessionStatus', () {
    test('maps every native constant to the matching enum value', () {
      // The ordering must mirror RDC_STATE_* in src/rdc_api.h exactly; a
      // mismatch here would mislabel session state in the UI rather than fail
      // loudly, so it is worth pinning down.
      expect(RdcSessionStatus.fromNative(0), RdcSessionStatus.idle);
      expect(RdcSessionStatus.fromNative(1), RdcSessionStatus.connecting);
      expect(RdcSessionStatus.fromNative(2), RdcSessionStatus.authenticating);
      expect(RdcSessionStatus.fromNative(3), RdcSessionStatus.connected);
      expect(RdcSessionStatus.fromNative(4), RdcSessionStatus.disconnecting);
      expect(RdcSessionStatus.fromNative(5), RdcSessionStatus.disconnected);
      expect(RdcSessionStatus.fromNative(6), RdcSessionStatus.failed);
    });

    test('falls back to failed for out-of-range values', () {
      expect(RdcSessionStatus.fromNative(-1), RdcSessionStatus.failed);
      expect(RdcSessionStatus.fromNative(99), RdcSessionStatus.failed);
    });

    test('treats only idle, disconnected and failed as terminal', () {
      expect(RdcSessionStatus.idle.isTerminal, isTrue);
      expect(RdcSessionStatus.disconnected.isTerminal, isTrue);
      expect(RdcSessionStatus.failed.isTerminal, isTrue);
      expect(RdcSessionStatus.connecting.isTerminal, isFalse);
      expect(RdcSessionStatus.connected.isTerminal, isFalse);
    });
  });

  group('RdcDesktopSize', () {
    test('computes aspect ratio', () {
      expect(
        const RdcDesktopSize(1920, 1080).aspectRatio,
        closeTo(16 / 9, 0.0001),
      );
      expect(
        const RdcDesktopSize(1280, 720).aspectRatio,
        closeTo(16 / 9, 0.0001),
      );
      expect(
        const RdcDesktopSize(1024, 768).aspectRatio,
        closeTo(4 / 3, 0.0001),
      );
    });

    test('does not divide by zero on a degenerate height', () {
      expect(const RdcDesktopSize(1024, 0).aspectRatio, 1);
    });

    test('compares by value', () {
      expect(
        const RdcDesktopSize(1920, 1080),
        const RdcDesktopSize(1920, 1080),
      );
      expect(
        const RdcDesktopSize(1920, 1080),
        isNot(const RdcDesktopSize(1920, 1200)),
      );
      expect(
        const RdcDesktopSize(1920, 1080).hashCode,
        const RdcDesktopSize(1920, 1080).hashCode,
      );
    });
  });

  group('RdcMouseAction', () {
    test('agrees with the bridge package and therefore with the C ABI', () {
      // The two lists are separate declarations of the same protocol values:
      // the engine layer cannot import the bridge (it has to stay usable by the
      // web stub), and the bridge cannot import the engine. Nothing but this
      // test keeps them in step, and a mismatch would silently send the wrong
      // mouse button rather than fail.
      expect(RdcMouseAction.move, bridge.RdcMouseAction.move);
      expect(RdcMouseAction.leftDown, bridge.RdcMouseAction.leftDown);
      expect(RdcMouseAction.leftUp, bridge.RdcMouseAction.leftUp);
      expect(RdcMouseAction.rightDown, bridge.RdcMouseAction.rightDown);
      expect(RdcMouseAction.rightUp, bridge.RdcMouseAction.rightUp);
      expect(RdcMouseAction.middleDown, bridge.RdcMouseAction.middleDown);
      expect(RdcMouseAction.middleUp, bridge.RdcMouseAction.middleUp);
      expect(RdcMouseAction.wheel, bridge.RdcMouseAction.wheel);
    });
  });

  group('RdcCursorKind', () {
    test('agrees with the bridge package and therefore with the C ABI', () {
      // The engine picks the kind by index out of the bridge's integer, so the
      // order of this enum is part of the contract rather than a detail: a
      // reordering would quietly draw the wrong pointer state, and the
      // ordinary arrow would become the hidden one.
      expect(RdcCursorKind.defaultArrow.index, bridge.RdcCursorKind.defaultArrow);
      expect(RdcCursorKind.hidden.index, bridge.RdcCursorKind.hidden);
      expect(RdcCursorKind.image.index, bridge.RdcCursorKind.image);
    });
  });

  group('RdcEngine.create', () {
    test('returns an engine rather than throwing when native code is absent', () {
      // On a machine without the built DLL this exercises the degrade path; on
      // one with it, the load succeeds. Either way construction must not throw,
      // because it happens during widget construction.
      final engine = RdcEngine.create();
      expect(engine.textureId, isA<int>());
      expect(engine.backendName, isNotEmpty);
    });
  });
}
