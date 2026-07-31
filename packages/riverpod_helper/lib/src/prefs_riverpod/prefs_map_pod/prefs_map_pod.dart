import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod_helper/src/prefs_riverpod/prefs_map_pod/decode_stored_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'prefs_map_pod.g.dart';

@riverpod
class PrefsMapPod extends _$PrefsMapPod {
  @override
  Future<Map<String, dynamic>?> build(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return decodeStoredMap(prefs.getString(key), key);
  }

  Future<void> removeValue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    // Set the new state directly rather than `ref.invalidateSelf()`: that
    // re-read SharedPreferences and put the provider back into AsyncLoading,
    // so every write made dependent widgets flicker.
    state = const AsyncData(null);
  }

  Future<void> setValue(Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
    state = AsyncData(value);
  }
}
