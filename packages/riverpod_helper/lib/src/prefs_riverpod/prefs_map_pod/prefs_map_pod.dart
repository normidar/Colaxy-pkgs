import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod_helper/src/prefs_riverpod/prefs_map_pod/decode_stored_map.dart';
import 'package:riverpod_helper/src/write_prefs_value.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'prefs_map_pod.g.dart';

@riverpod
class PrefsMapPod extends _$PrefsMapPod {
  @override
  Future<Map<String, dynamic>?> build(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return decodeStoredMap(prefs.getString(key), key);
  }

  // The writes go through `writePrefsValue` so that reaching this pod with
  // `ref.read(...notifier)` — which does not subscribe, and so lets an
  // auto-dispose provider die at the first `await` — cannot throw
  // `Cannot use the Ref ... after it has been disposed`.

  Future<void> removeValue() => writePrefsValue(
    ref: ref,
    key: key,
    write: (prefs, key) => prefs.remove(key),
    // Set the new state directly rather than `ref.invalidateSelf()`: that
    // re-read SharedPreferences and put the provider back into AsyncLoading,
    // so every write made dependent widgets flicker.
    publishState: () => state = const AsyncData(null),
  );

  Future<void> setValue(Map<String, dynamic> value) => writePrefsValue(
    ref: ref,
    key: key,
    write: (prefs, key) => prefs.setString(key, jsonEncode(value)),
    publishState: () => state = AsyncData(value),
  );
}
