import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod_helper/src/prefs_riverpod/prefs_map_pod/decode_stored_map.dart';
import 'package:riverpod_helper/src/write_prefs_value.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'prefs_map_pod.g.dart';

/// A keep-alive JSON map stored in SharedPreferences.
///
/// The auto-dispose family had a map pod but this one did not, so a map was the
/// only type you could not keep alive.
@Riverpod(keepAlive: true)
class PrefsAliveMapPod extends _$PrefsAliveMapPod {
  @override
  Future<Map<String, dynamic>?> build(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return decodeStoredMap(prefs.getString(key), key);
  }

  // Keeping alive is redundant for a keepAlive pod, but the container this pod
  // lives in can still be disposed mid-write, and matching the auto-dispose
  // pods keeps one write path to reason about.

  Future<void> removeValue() => writePrefsValue(
    ref: ref,
    key: key,
    write: (prefs, key) => prefs.remove(key),
    publishState: () => state = const AsyncData(null),
  );

  Future<void> setValue(Map<String, dynamic> value) => writePrefsValue(
    ref: ref,
    key: key,
    write: (prefs, key) => prefs.setString(key, jsonEncode(value)),
    publishState: () => state = AsyncData(value),
  );
}
