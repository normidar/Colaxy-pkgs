import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod_helper/src/prefs_riverpod/prefs_map_pod/decode_stored_map.dart';
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

  Future<void> removeValue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    state = const AsyncData(null);
  }

  Future<void> setValue(Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
    state = AsyncData(value);
  }
}
