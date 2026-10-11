/// Tolerant coercion helpers for reading persisted models.
///
/// The store is a plain JSON file the user could hand-edit, and older builds
/// wrote documents with fewer keys. A `as T` cast on such a value throws and
/// takes the whole load down with it, so every read of a persisted field goes
/// through one of these instead.
library;

/// The value as a string-keyed map, or an empty map when it is anything else.
Map<String, Object?> asMapOrEmpty(Object? value) =>
    value is Map<String, Object?> ? value : const {};

/// The value as a list, or an empty list when it is anything else.
List<Object?> asList(Object? value) =>
    value is List<Object?> ? value : const [];

String asString(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

/// Absent, null and wrong-typed all collapse to null.
String? asStringOrNull(Object? value) => value is String ? value : null;

int asInt(Object? value, int fallback) => value is int ? value : fallback;

int? asIntOrNull(Object? value) => value is int ? value : null;

bool asBool(Object? value, bool fallback) => value is bool ? value : fallback;

DateTime? asDateOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// Splits a user-typed host into a host name and an optional port.
///
/// Deliberately not built on [Uri]: `Uri.parse('rdp://not a host')` silently
/// percent-encodes the result, so a host name containing a space or other
/// punctuation would come back mangled. Here anything that is not a clean
/// `host:port` is passed through untouched, which is the safe default when it
/// is the user's own typing being interpreted.
///
/// Handles `host`, `host:port`, `[::1]` and `[::1]:port`.
({String hostname, int? port}) splitHostPort(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return (hostname: value, port: null);
  }

  if (trimmed.startsWith('[')) {
    final closing = trimmed.indexOf(']');
    if (closing > 0) {
      final host = trimmed.substring(1, closing);
      final remainder = trimmed.substring(closing + 1);
      if (remainder.startsWith(':')) {
        return (hostname: host, port: int.tryParse(remainder.substring(1)));
      }
      return (hostname: host, port: null);
    }
    // Unbalanced bracket; treat it as an opaque host rather than guessing.
    return (hostname: trimmed, port: null);
  }

  // `> 0` so a leading colon is not mistaken for a separator. A bare IPv6
  // address lands here too, fails the integer parse, and passes through whole.
  final colon = trimmed.lastIndexOf(':');
  if (colon > 0) {
    final port = int.tryParse(trimmed.substring(colon + 1));
    if (port != null) {
      return (hostname: trimmed.substring(0, colon), port: port);
    }
  }

  return (hostname: trimmed, port: null);
}
