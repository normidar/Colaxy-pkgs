import 'dart:convert';

/// Decodes a JSON object previously written by a prefs map pod.
///
/// Returns null when nothing is stored. A value that is not a JSON object —
/// written by an older version of the app, or by something else under the same
/// key — used to surface as an unattributed `CastError`/`FormatException` from
/// inside the provider; this names the key instead.
Map<String, dynamic>? decodeStoredMap(String? raw, String key) {
  if (raw == null) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (e) {
    throw FormatException(
      'SharedPreferences key "$key" does not hold valid JSON: ${e.message}',
      raw,
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw FormatException(
      'SharedPreferences key "$key" holds ${decoded.runtimeType}, '
      'expected a JSON object.',
      raw,
    );
  }
  return decoded;
}
