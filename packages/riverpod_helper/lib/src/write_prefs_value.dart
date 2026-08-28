import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a prefs pod's value and publishes the result as its new state.
///
/// This exists because writing through `ref.read(somePodProvider(k).notifier)`
/// — the obvious way to change a setting from an event handler — used to throw
/// on the auto-dispose pods. `ref.read` does not subscribe, so the provider has
/// no listener and is disposed as soon as the write's first `await` yields.
/// Control then came back to a method that touched a dead [Ref], and
/// `state = ...` threw `Cannot use the Ref of ... after it has been disposed`.
/// The throw landed *after* SharedPreferences had already stored the value, so
/// the setting looked like it had failed but reappeared on the next launch.
///
/// Two things keep that from happening:
///
/// 1. A [Ref.keepAlive] link taken *synchronously*, before the first `await`.
///    `ref.read(...).setValue(...)` runs this method's synchronous prologue in
///    the same microtask as the `read`, so the provider is still alive here and
///    stays alive until the write finishes.
/// 2. [key] is a parameter rather than something read inside this function, so
///    callers evaluate the notifier's `key` getter at the call site — before
///    the first `await` — instead of reaching through the [Ref] afterwards.
///
/// If the provider is *already* disposed when the write starts (a notifier
/// held across an event loop turn, say), the write still goes to disk and
/// [publishState] is skipped: there is no live state left to publish, and the
/// next read of the provider picks the value up from SharedPreferences.
///
/// ## Parameters
///
/// ### Required
/// - **[ref]**: The calling notifier's `ref`.
/// - **[key]**: The SharedPreferences key, read from the notifier's `key`
///   getter at the call site.
/// - **[write]**: Performs the actual SharedPreferences write.
/// - **[publishState]**: Assigns the pod's new state. Only invoked while the
///   provider is still mounted.
///
/// ## Example
///
/// ```dart
/// Future<void> setValue(bool value) => writePrefsValue(
///       ref: ref,
///       key: key,
///       write: (prefs, key) => prefs.setBool(key, value),
///       publishState: () => state = AsyncData(value),
///     );
/// ```
Future<void> writePrefsValue({
  required Ref ref,
  required String key,
  required Future<void> Function(SharedPreferences prefs, String key) write,
  required void Function() publishState,
}) async {
  final link = ref.mounted ? ref.keepAlive() : null;
  try {
    final prefs = await SharedPreferences.getInstance();
    await write(prefs, key);
    if (ref.mounted) publishState();
  } finally {
    link?.close();
  }
}
