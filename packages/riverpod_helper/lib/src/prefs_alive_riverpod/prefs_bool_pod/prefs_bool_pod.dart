// ignore: lines_longer_than_80_chars
// ignore_for_file: public_member_api_docs, document_ignores, avoid_positional_boolean_parameters

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod_helper/src/write_prefs_value.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'prefs_bool_pod.g.dart';

@Riverpod(keepAlive: true)
class PrefsAliveBoolPod extends _$PrefsAliveBoolPod {
  @override
  Future<bool?> build(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  // Keeping alive is redundant for a keepAlive pod, but the container this pod
  // lives in can still be disposed mid-write, and matching the auto-dispose
  // pods keeps one write path to reason about.

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
