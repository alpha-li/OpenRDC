import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openrdc/features/session/scancode_map.dart';

void main() {
  group('scancodeFor', () {
    test('maps letters to their PS/2 set 1 codes', () {
      // Spot checks across the alphabet, including the ones whose codes are
      // least guessable (q and a sit at 0x10 and 0x1E rather than in any
      // alphabetical run).
      expect(scancodeFor(PhysicalKeyboardKey.keyA)?.scancode, 0x1E);
      expect(scancodeFor(PhysicalKeyboardKey.keyQ)?.scancode, 0x10);
      expect(scancodeFor(PhysicalKeyboardKey.keyZ)?.scancode, 0x2C);
      expect(scancodeFor(PhysicalKeyboardKey.keyM)?.scancode, 0x32);
    });

    test('maps the digit row', () {
      expect(scancodeFor(PhysicalKeyboardKey.digit1)?.scancode, 0x02);
      expect(scancodeFor(PhysicalKeyboardKey.digit0)?.scancode, 0x0B);
    });

    test('marks the navigation cluster as extended', () {
      // The arrow and navigation keys share codes with the keypad; only the
      // extended bit distinguishes them, so getting it wrong turns an arrow
      // into a number.
      expect(scancodeFor(PhysicalKeyboardKey.arrowUp)?.extended, isTrue);
      expect(scancodeFor(PhysicalKeyboardKey.arrowUp)?.scancode, 0x48);
      expect(scancodeFor(PhysicalKeyboardKey.delete)?.extended, isTrue);
      expect(scancodeFor(PhysicalKeyboardKey.home)?.extended, isTrue);
      expect(scancodeFor(PhysicalKeyboardKey.pageDown)?.extended, isTrue);
    });

    test('keeps keypad equivalents non-extended so they stay distinct', () {
      final keypad8 = scancodeFor(PhysicalKeyboardKey.numpad8);
      final arrowUp = scancodeFor(PhysicalKeyboardKey.arrowUp);
      expect(keypad8?.scancode, arrowUp?.scancode);
      expect(keypad8?.extended, isFalse);
      expect(arrowUp?.extended, isTrue);
    });

    test('distinguishes left and right modifiers', () {
      final leftControl = scancodeFor(PhysicalKeyboardKey.controlLeft);
      final rightControl = scancodeFor(PhysicalKeyboardKey.controlRight);
      expect(leftControl?.scancode, 0x1D);
      expect(rightControl?.scancode, 0x1D);
      expect(leftControl?.extended, isFalse);
      expect(rightControl?.extended, isTrue);

      // Shift is the exception: the two sides use genuinely different codes.
      expect(scancodeFor(PhysicalKeyboardKey.shiftLeft)?.scancode, 0x2A);
      expect(scancodeFor(PhysicalKeyboardKey.shiftRight)?.scancode, 0x36);
      expect(scancodeFor(PhysicalKeyboardKey.shiftLeft)?.extended, isFalse);
      expect(scancodeFor(PhysicalKeyboardKey.shiftRight)?.extended, isFalse);
    });

    test('maps the function keys, including the F11/F12 discontinuity', () {
      expect(scancodeFor(PhysicalKeyboardKey.f1)?.scancode, 0x3B);
      expect(scancodeFor(PhysicalKeyboardKey.f10)?.scancode, 0x44);
      // F11 and F12 are not contiguous with F1-F10 in this layout.
      expect(scancodeFor(PhysicalKeyboardKey.f11)?.scancode, 0x57);
      expect(scancodeFor(PhysicalKeyboardKey.f12)?.scancode, 0x58);
    });

    test('returns null for keys with no scancode', () {
      // Falling back to text input is the only way to produce these, so a null
      // here is a real answer rather than a gap in the table.
      expect(scancodeFor(PhysicalKeyboardKey.audioVolumeUp), isNull);
      expect(scancodeFor(PhysicalKeyboardKey.browserBack), isNull);
    });

    test(
      'does not map any two distinct keys to the same scancode and flag pair',
      () {
        // A collision would make one key type another's character. Keypad keys
        // legitimately share codes with the navigation cluster, which is why the
        // extended flag is part of the identity being compared.
        final seen = <String, PhysicalKeyboardKey>{};
        for (final key in _everyMappedKey) {
          final mapped = scancodeFor(key);
          expect(mapped, isNotNull, reason: '${_name(key)} should be mapped');
          if (mapped == null) {
            continue;
          }
          final identity = '${mapped.scancode}:${mapped.extended}';
          final previous = seen[identity];
          // Compared with an if rather than expect(reason:), because expect
          // evaluates its reason eagerly and the message needs the non-null value.
          if (previous != null) {
            fail('${_name(key)} collides with ${_name(previous)} at $identity');
          }
          seen[identity] = key;
        }
      },
    );
  });

  group('isModifierOrShortcutKey', () {
    test('recognises every modifier', () {
      expect(isModifierOrShortcutKey(PhysicalKeyboardKey.controlLeft), isTrue);
      expect(isModifierOrShortcutKey(PhysicalKeyboardKey.shiftRight), isTrue);
      expect(isModifierOrShortcutKey(PhysicalKeyboardKey.altLeft), isTrue);
      expect(isModifierOrShortcutKey(PhysicalKeyboardKey.metaLeft), isTrue);
    });

    test('does not claim ordinary keys', () {
      expect(isModifierOrShortcutKey(PhysicalKeyboardKey.keyA), isFalse);
      expect(isModifierOrShortcutKey(PhysicalKeyboardKey.enter), isFalse);
    });
  });
}

/// Every physical key the table is expected to cover, grouped as the table is.
const List<PhysicalKeyboardKey> _everyMappedKey = [
  PhysicalKeyboardKey.keyA,
  PhysicalKeyboardKey.keyB,
  PhysicalKeyboardKey.keyC,
  PhysicalKeyboardKey.keyD,
  PhysicalKeyboardKey.keyE,
  PhysicalKeyboardKey.keyF,
  PhysicalKeyboardKey.keyG,
  PhysicalKeyboardKey.keyH,
  PhysicalKeyboardKey.keyI,
  PhysicalKeyboardKey.keyJ,
  PhysicalKeyboardKey.keyK,
  PhysicalKeyboardKey.keyL,
  PhysicalKeyboardKey.keyM,
  PhysicalKeyboardKey.keyN,
  PhysicalKeyboardKey.keyO,
  PhysicalKeyboardKey.keyP,
  PhysicalKeyboardKey.keyQ,
  PhysicalKeyboardKey.keyR,
  PhysicalKeyboardKey.keyS,
  PhysicalKeyboardKey.keyT,
  PhysicalKeyboardKey.keyU,
  PhysicalKeyboardKey.keyV,
  PhysicalKeyboardKey.keyW,
  PhysicalKeyboardKey.keyX,
  PhysicalKeyboardKey.keyY,
  PhysicalKeyboardKey.keyZ,

  PhysicalKeyboardKey.digit1,
  PhysicalKeyboardKey.digit2,
  PhysicalKeyboardKey.digit3,
  PhysicalKeyboardKey.digit4,
  PhysicalKeyboardKey.digit5,
  PhysicalKeyboardKey.digit6,
  PhysicalKeyboardKey.digit7,
  PhysicalKeyboardKey.digit8,
  PhysicalKeyboardKey.digit9,
  PhysicalKeyboardKey.digit0,

  PhysicalKeyboardKey.enter,
  PhysicalKeyboardKey.escape,
  PhysicalKeyboardKey.backspace,
  PhysicalKeyboardKey.tab,
  PhysicalKeyboardKey.space,
  PhysicalKeyboardKey.capsLock,

  PhysicalKeyboardKey.minus,
  PhysicalKeyboardKey.equal,
  PhysicalKeyboardKey.bracketLeft,
  PhysicalKeyboardKey.bracketRight,
  PhysicalKeyboardKey.backslash,
  PhysicalKeyboardKey.semicolon,
  PhysicalKeyboardKey.quote,
  PhysicalKeyboardKey.backquote,
  PhysicalKeyboardKey.comma,
  PhysicalKeyboardKey.period,
  PhysicalKeyboardKey.slash,

  PhysicalKeyboardKey.f1,
  PhysicalKeyboardKey.f2,
  PhysicalKeyboardKey.f3,
  PhysicalKeyboardKey.f4,
  PhysicalKeyboardKey.f5,
  PhysicalKeyboardKey.f6,
  PhysicalKeyboardKey.f7,
  PhysicalKeyboardKey.f8,
  PhysicalKeyboardKey.f9,
  PhysicalKeyboardKey.f10,
  PhysicalKeyboardKey.f11,
  PhysicalKeyboardKey.f12,

  PhysicalKeyboardKey.printScreen,
  PhysicalKeyboardKey.scrollLock,

  PhysicalKeyboardKey.insert,
  PhysicalKeyboardKey.home,
  PhysicalKeyboardKey.pageUp,
  PhysicalKeyboardKey.delete,
  PhysicalKeyboardKey.end,
  PhysicalKeyboardKey.pageDown,
  PhysicalKeyboardKey.arrowRight,
  PhysicalKeyboardKey.arrowLeft,
  PhysicalKeyboardKey.arrowDown,
  PhysicalKeyboardKey.arrowUp,

  PhysicalKeyboardKey.numLock,
  PhysicalKeyboardKey.numpadDivide,
  PhysicalKeyboardKey.numpadMultiply,
  PhysicalKeyboardKey.numpadSubtract,
  PhysicalKeyboardKey.numpadAdd,
  PhysicalKeyboardKey.numpadEnter,
  PhysicalKeyboardKey.numpad1,
  PhysicalKeyboardKey.numpad2,
  PhysicalKeyboardKey.numpad3,
  PhysicalKeyboardKey.numpad4,
  PhysicalKeyboardKey.numpad5,
  PhysicalKeyboardKey.numpad6,
  PhysicalKeyboardKey.numpad7,
  PhysicalKeyboardKey.numpad8,
  PhysicalKeyboardKey.numpad9,
  PhysicalKeyboardKey.numpad0,
  PhysicalKeyboardKey.numpadDecimal,

  PhysicalKeyboardKey.controlLeft,
  PhysicalKeyboardKey.shiftLeft,
  PhysicalKeyboardKey.altLeft,
  PhysicalKeyboardKey.metaLeft,
  PhysicalKeyboardKey.controlRight,
  PhysicalKeyboardKey.shiftRight,
  PhysicalKeyboardKey.altRight,
  PhysicalKeyboardKey.metaRight,
];

String _name(PhysicalKeyboardKey key) =>
    'USB 0x${key.usbHidUsage.toRadixString(16).padLeft(8, '0')}';
