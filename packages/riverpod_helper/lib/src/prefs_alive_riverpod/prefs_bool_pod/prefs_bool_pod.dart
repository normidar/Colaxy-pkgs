// ignore: lines_longer_than_80_chars
// ignore_for_file: public_member_api_docs, document_ignores, avoid_positional_boolean_parameters

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'prefs_bool_pod.g.dart';

@Riverpod(keepAlive: true)
class PrefsAliveBoolPod extends _$PrefsAliveBoolPod {
  @override
  Future<bool?> build(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  Future<void> removeValue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    // Set the new state directly rather than `ref.invalidateSelf()`: that
    // re-read SharedPreferences and put the provider back into AsyncLoading,
    // so every write made dependent widgets flicker.
    state = const AsyncData(null);
  }

  Future<void> setValue(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    state = AsyncData(value);
  }
}
