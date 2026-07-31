// ignore_for_file: avoid_positional_boolean_parameters, document_ignores

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'prefs_bool_pod.g.dart';

@riverpod
class PrefsBoolPod extends _$PrefsBoolPod {
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
