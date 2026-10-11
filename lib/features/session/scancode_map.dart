/// Maps Flutter physical keys to PS/2 set 1 scancodes.
///
/// RDP transports scancodes, not characters or virtual keys. Going through the
/// *physical* key is what makes the remote session honour its own keyboard
/// layout: pressing the key where `A` sits on a US layout produces the character
/// that layout puts there on the host, which is exactly what a hardware KVM
/// would do and what users expect.
///
/// Flutter exposes USB HID usage codes on [PhysicalKeyboardKey], so the table is
/// keyed by those. Keys absent from the table fall back to text input via
/// `rdc_text`, which is the only way to produce characters that no scancode can
/// express.
library;

import 'package:flutter/services.dart';

/// A key press translated for the native input queue.
class RemoteKey {
  const RemoteKey(this.scancode, {this.extended = false});

  /// The 8-bit PS/2 set 1 scancode.
  final int scancode;

  /// True for the grey navigation cluster, keypad divide/enter and the
  /// right-hand modifiers. The RDP protocol distinguishes these from their
  /// numpad and left-hand twins solely by this bit.
  final bool extended;
}

/// Resolves a physical key, or null when the key has no scancode.
RemoteKey? scancodeFor(PhysicalKeyboardKey key) => _table[key.usbHidUsage];

/// Whether [key] should be sent as text rather than as a scancode.
///
/// Modifiers and shortcuts must go through scancodes so the host sees the real
/// key combination; anything else that produces a character is better sent as
/// text, because that is layout-independent.
bool isModifierOrShortcutKey(PhysicalKeyboardKey key) =>
    _modifierUsages.contains(key.usbHidUsage);

const Set<int> _modifierUsages = {
  0x000700e0, // left control
  0x000700e1, // left shift
  0x000700e2, // left alt
  0x000700e3, // left gui
  0x000700e4, // right control
  0x000700e5, // right shift
  0x000700e6, // right alt
  0x000700e7, // right gui
};

/// USB HID usage -> PS/2 set 1 scancode.
///
/// Only keys that have a scancode are listed. Media keys, browser keys and the
/// like are deliberately omitted: they would need RDP's extended scancode
/// sequence, and sending a wrong one is worse than falling back to text.
const Map<int, RemoteKey> _table = {
  // Letters
  0x00070004: RemoteKey(0x1E), // a
  0x00070005: RemoteKey(0x30), // b
  0x00070006: RemoteKey(0x2E), // c
  0x00070007: RemoteKey(0x20), // d
  0x00070008: RemoteKey(0x12), // e
  0x00070009: RemoteKey(0x21), // f
  0x0007000A: RemoteKey(0x22), // g
  0x0007000B: RemoteKey(0x23), // h
  0x0007000C: RemoteKey(0x17), // i
  0x0007000D: RemoteKey(0x24), // j
  0x0007000E: RemoteKey(0x25), // k
  0x0007000F: RemoteKey(0x26), // l
  0x00070010: RemoteKey(0x32), // m
  0x00070011: RemoteKey(0x31), // n
  0x00070012: RemoteKey(0x18), // o
  0x00070013: RemoteKey(0x19), // p
  0x00070014: RemoteKey(0x10), // q
  0x00070015: RemoteKey(0x13), // r
  0x00070016: RemoteKey(0x1F), // s
  0x00070017: RemoteKey(0x14), // t
  0x00070018: RemoteKey(0x16), // u
  0x00070019: RemoteKey(0x2F), // v
  0x0007001A: RemoteKey(0x11), // w
  0x0007001B: RemoteKey(0x2D), // x
  0x0007001C: RemoteKey(0x15), // y
  0x0007001D: RemoteKey(0x2C), // z
  // Digits along the top row
  0x0007001E: RemoteKey(0x02), // 1
  0x0007001F: RemoteKey(0x03), // 2
  0x00070020: RemoteKey(0x04), // 3
  0x00070021: RemoteKey(0x05), // 4
  0x00070022: RemoteKey(0x06), // 5
  0x00070023: RemoteKey(0x07), // 6
  0x00070024: RemoteKey(0x08), // 7
  0x00070025: RemoteKey(0x09), // 8
  0x00070026: RemoteKey(0x0A), // 9
  0x00070027: RemoteKey(0x0B), // 0
  // Editing and control
  0x00070028: RemoteKey(0x1C), // enter
  0x00070029: RemoteKey(0x01), // escape
  0x0007002A: RemoteKey(0x0E), // backspace
  0x0007002B: RemoteKey(0x0F), // tab
  0x0007002C: RemoteKey(0x39), // space
  0x00070039: RemoteKey(0x3A), // caps lock
  // Punctuation
  0x0007002D: RemoteKey(0x0C), // -
  0x0007002E: RemoteKey(0x0D), // =
  0x0007002F: RemoteKey(0x1A), // [
  0x00070030: RemoteKey(0x1B), // ]
  0x00070031: RemoteKey(0x2B), // backslash
  0x00070033: RemoteKey(0x27), // ;
  0x00070034: RemoteKey(0x28), // '
  0x00070035: RemoteKey(0x29), // `
  0x00070036: RemoteKey(0x33), // ,
  0x00070037: RemoteKey(0x34), // .
  0x00070038: RemoteKey(0x35), // /
  // Function keys
  0x0007003A: RemoteKey(0x3B), // F1
  0x0007003B: RemoteKey(0x3C), // F2
  0x0007003C: RemoteKey(0x3D), // F3
  0x0007003D: RemoteKey(0x3E), // F4
  0x0007003E: RemoteKey(0x3F), // F5
  0x0007003F: RemoteKey(0x40), // F6
  0x00070040: RemoteKey(0x41), // F7
  0x00070041: RemoteKey(0x42), // F8
  0x00070042: RemoteKey(0x43), // F9
  0x00070043: RemoteKey(0x44), // F10
  0x00070044: RemoteKey(0x57), // F11
  0x00070045: RemoteKey(0x58), // F12
  // System
  0x00070046: RemoteKey(0x37, extended: true), // print screen
  0x00070047: RemoteKey(0x46), // scroll lock
  // Pause/Break is deliberately absent. Its PS/2 set 1 encoding is the
  // multi-byte sequence E1 1D 45, not a single scancode, so the only single
  // byte that comes close is 0x45 -- which is Num Lock, and mapping it there
  // would silently turn Pause into Num Lock on the remote side. Sending it
  // properly needs FreeRDP's dedicated pause event, which is not plumbed
  // through yet; until then this key does nothing, which is the lesser evil.

  // Navigation cluster — all extended
  0x00070049: RemoteKey(0x52, extended: true), // insert
  0x0007004A: RemoteKey(0x47, extended: true), // home
  0x0007004B: RemoteKey(0x49, extended: true), // page up
  0x0007004C: RemoteKey(0x53, extended: true), // delete
  0x0007004D: RemoteKey(0x4F, extended: true), // end
  0x0007004E: RemoteKey(0x51, extended: true), // page down
  0x0007004F: RemoteKey(0x4D, extended: true), // right
  0x00070050: RemoteKey(0x4B, extended: true), // left
  0x00070051: RemoteKey(0x50, extended: true), // down
  0x00070052: RemoteKey(0x48, extended: true), // up
  // Keypad
  0x00070053: RemoteKey(0x45), // num lock
  0x00070054: RemoteKey(0x35, extended: true), // keypad /
  0x00070055: RemoteKey(0x37), // keypad *
  0x00070056: RemoteKey(0x4A), // keypad -
  0x00070057: RemoteKey(0x4E), // keypad +
  0x00070058: RemoteKey(0x1C, extended: true), // keypad enter
  0x00070059: RemoteKey(0x4F), // keypad 1
  0x0007005A: RemoteKey(0x50), // keypad 2
  0x0007005B: RemoteKey(0x51), // keypad 3
  0x0007005C: RemoteKey(0x4B), // keypad 4
  0x0007005D: RemoteKey(0x4C), // keypad 5
  0x0007005E: RemoteKey(0x4D), // keypad 6
  0x0007005F: RemoteKey(0x47), // keypad 7
  0x00070060: RemoteKey(0x48), // keypad 8
  0x00070061: RemoteKey(0x49), // keypad 9
  0x00070062: RemoteKey(0x52), // keypad 0
  0x00070063: RemoteKey(0x53), // keypad .
  // Modifiers. The right-hand variants are the same scancode with the extended
  // bit, which is how the host tells them apart.
  0x000700E0: RemoteKey(0x1D), // left control
  0x000700E1: RemoteKey(0x2A), // left shift
  0x000700E2: RemoteKey(0x38), // left alt
  0x000700E3: RemoteKey(0x5B, extended: true), // left gui
  0x000700E4: RemoteKey(0x1D, extended: true), // right control
  0x000700E5: RemoteKey(0x36), // right shift
  0x000700E6: RemoteKey(0x38, extended: true), // right alt
  0x000700E7: RemoteKey(0x5C, extended: true), // right gui
};
