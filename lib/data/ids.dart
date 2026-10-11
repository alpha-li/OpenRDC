/// Identifier generation for stored records.
///
/// Deliberately not a UUID dependency: ids only ever need to be unique within
/// one user's connection file, and they are never sent anywhere. A timestamp
/// plus randomness is collision-free at any plausible scale while staying
/// readable in the JSON, which matters when someone opens the file to see why a
/// gateway stopped resolving.
library;

import 'dart:math';

final Random _random = Random();

const String _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// A short, sortable, collision-resistant id: `<millis>-<6 random chars>`.
String newId() {
  final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final suffix = String.fromCharCodes(
    List.generate(
      6,
      (_) => _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
    ),
  );
  return '$stamp-$suffix';
}
