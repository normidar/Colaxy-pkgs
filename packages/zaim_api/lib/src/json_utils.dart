/// Defensive JSON coercion helpers shared by every model in this package.
///
/// Zaim is loose about types: an `id` can arrive as `381` or as `"381"`, an
/// absent foreign key arrives as `0` rather than `null`, and new fields are
/// added to responses without notice. Every model parses through the helpers
/// below so that none of those cases throws.
library;

/// The fixed offset every Zaim timestamp is expressed in.
///
/// Zaim renders `created` / `modified` / `profile_modified` as a bare
/// `"YYYY-MM-DD HH:MM:SS"` wall-clock string in Japan Standard Time, which has
/// no daylight saving, so a constant offset is exact.
const Duration jstOffset = Duration(hours: 9);

/// Reads [key] from [json] as an `int`, tolerating numeric strings.
///
/// Returns [fallback] when the key is missing or cannot be read as a number.
int asInt(Map<String, dynamic> json, String key, {int fallback = 0}) =>
    asIntOrNull(json, key) ?? fallback;

/// Reads [key] from [json] as an `int`, or `null` when it is missing,
/// `null`, or not parseable as a number.
int? asIntOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// Reads [key] as a Zaim foreign key, mapping the "no value" sentinel `0` to
/// `null`.
///
/// Zaim returns `0` rather than `null` for unset references such as
/// `from_account_id` or `genre_id`; the models expose that as `null` so that
/// callers cannot accidentally treat `0` as a real id.
int? asId(Map<String, dynamic> json, String key) {
  final value = asIntOrNull(json, key);
  if (value == null || value == 0) return null;
  return value;
}

/// Reads [key] from [json] as a `String`.
///
/// Numbers are stringified. Returns [fallback] when the key is missing or
/// `null`.
String asString(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) =>
    asStringOrNull(json, key) ?? fallback;

/// Reads [key] from [json] as a `String`, or `null` when it is missing or
/// `null`. Empty strings are preserved as empty strings.
String? asStringOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

/// Reads [key] as a `Y-m-d` date such as `2011-11-07`.
///
/// The result is a local `DateTime` at midnight: Zaim dates carry no time and
/// no zone, so they are treated as plain calendar dates.
DateTime? asDate(Map<String, dynamic> json, String key) {
  final raw = asStringOrNull(json, key);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw.trim());
}

/// Reads [key] as a `"YYYY-MM-DD HH:MM:SS"` JST timestamp.
///
/// The returned `DateTime` is in UTC and denotes the same instant, so it can
/// be compared with timestamps from any other source. Use
/// [formatZaimTimestamp] to render it back in Zaim's format.
DateTime? asTimestamp(Map<String, dynamic> json, String key) {
  final raw = asStringOrNull(json, key)?.trim();
  if (raw == null || raw.isEmpty) return null;
  // Attach the JST offset so `DateTime.parse` resolves the wall clock to a
  // real instant instead of guessing the host's local zone.
  final parsed = DateTime.tryParse('$raw+09:00');
  if (parsed != null) return parsed.toUtc();
  return DateTime.tryParse(raw)?.toUtc();
}

/// Reads [key] as a Unix timestamp in seconds (Zaim's `requested` field).
DateTime? asUnixTimestamp(Map<String, dynamic> json, String key) {
  final seconds = asIntOrNull(json, key);
  if (seconds == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

/// Reads [key] as a nested JSON object, or `null` when it is missing or is
/// not an object.
Map<String, dynamic>? asMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

/// Reads [key] as a list of JSON objects, skipping any element that is not an
/// object. Returns an empty list when the key is missing.
List<Map<String, dynamic>> asMapList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) return const [];
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((e) => e.cast<String, dynamic>())
      .toList(growable: false);
}

/// Formats [date] as the `Y-m-d` string Zaim expects in request parameters.
String formatZaimDate(DateTime date) {
  final d = date.isUtc ? date.toLocal() : date;
  return '${_pad(d.year, 4)}-${_pad(d.month, 2)}-${_pad(d.day, 2)}';
}

/// Formats [timestamp] as the `"YYYY-MM-DD HH:MM:SS"` JST string Zaim uses in
/// responses. The inverse of [asTimestamp].
String formatZaimTimestamp(DateTime timestamp) {
  final jst = timestamp.toUtc().add(jstOffset);
  return '${_pad(jst.year, 4)}-${_pad(jst.month, 2)}-${_pad(jst.day, 2)} '
      '${_pad(jst.hour, 2)}:${_pad(jst.minute, 2)}:${_pad(jst.second, 2)}';
}

/// Converts [timestamp] back to whole Unix seconds.
int toUnixSeconds(DateTime timestamp) =>
    timestamp.millisecondsSinceEpoch ~/ 1000;

String _pad(int value, int width) => value.toString().padLeft(width, '0');
