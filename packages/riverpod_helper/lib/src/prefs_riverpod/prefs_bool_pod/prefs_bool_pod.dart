// ignore_for_file: avoid_positional_boolean_parameters, document_ignores

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod_helper/src/write_prefs_value.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'prefs_bool_pod.g.dart';

@riverpod
class PrefsBoolPod extends _$PrefsBoolPod {
  @override
  Future<bool?> build(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
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

  Future<void> setValue(bool value) => writePrefsValue(
    ref: ref,
    key: key,
    write: (prefs, key) => prefs.setBool(key, value),
    publishState: () => state = AsyncData(value),
  );
}
