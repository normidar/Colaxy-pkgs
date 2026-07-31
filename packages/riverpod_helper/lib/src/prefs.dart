import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when a [Prefs] call is made with a type SharedPreferences cannot
/// store.
///
/// Only [bool], [int], [double], [String] and `List<String>` are supported.
class UnsupportedPrefsTypeError extends ArgumentError {
  /// Creates an error describing the unsupported [type].
  UnsupportedPrefsTypeError(this.type)
    : super.value(
        type,
        'type',
        'SharedPreferences cannot store this type. Supported types are '
            'bool, int, double, String and List<String>.',
      );

  /// The type that was rejected.
  final Object? type;
}

/// Type-safe convenience wrapper around [SharedPreferences].
class Prefs {
  /// This class is not meant to be instantiated.
  const Prefs._();

  /// Check if key exists
  static Future<bool> contains(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
  }

  /// get value or [defaultValue] if not exists
  ///
  /// Throws an [UnsupportedPrefsTypeError] if `T` is not a type
  /// SharedPreferences can store.
  static Future<T> get<T>(String key, T defaultValue) async {
    return await getOrNull<T>(key) ?? defaultValue;
  }

  /// get value or null if not exists
  ///
  /// Throws an [UnsupportedPrefsTypeError] if `T` is not a type
  /// SharedPreferences can store.
  static Future<T?> getOrNull<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    // There is no value to pattern match on when reading, so the stored type
    // has to be selected from the type argument. `_typeIs` accepts both `X` and
    // `X?`, because `getOrNull<String?>` is a reasonable thing to write and an
    // exact match against `String` would reject it.
    if (_typeIs<T, bool>()) return prefs.getBool(key) as T?;
    if (_typeIs<T, int>()) return prefs.getInt(key) as T?;
    if (_typeIs<T, double>()) return prefs.getDouble(key) as T?;
    if (_typeIs<T, String>()) return prefs.getString(key) as T?;
    if (_typeIs<T, List<String>>()) return prefs.getStringList(key) as T?;
    // Previously this fell through to `prefs.get(key) as T?`, which turned an
    // unsupported type into a confusing CastError at some later point.
    throw UnsupportedPrefsTypeError(T);
  }

  /// Whether `T` is `S` or `S?`.
  ///
  /// Comparing `T == S` cannot see through nullability, and there is no way to
  /// write a `Type` literal for `S?`; going through a generic list makes the
  /// subtype check the compiler already knows how to do.
  static bool _typeIs<T, S>() => <T>[] is List<S?>;

  /// Get value if exists, otherwise set [defaultValue] and return it.
  static Future<T> getOrSet<T>(String key, T defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(key)) {
      return get(key, defaultValue);
    } else {
      return set(key, defaultValue);
    }
  }

  /// Remove the value stored under [key].
  static Future<bool> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(key);
  }

  /// Store [value] under [key] and return it.
  ///
  /// Throws an [UnsupportedPrefsTypeError] for values SharedPreferences cannot
  /// store.
  static Future<T> set<T>(String key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    // Switch on the value rather than on `T`: when the call site goes through a
    // `dynamic`/`Object` variable, `T` is inferred as `Object` and a static
    // `T == bool` check would wrongly report the value as unsupported.
    switch (value) {
      case final bool v:
        await prefs.setBool(key, v);
      case final int v:
        await prefs.setInt(key, v);
      case final double v:
        await prefs.setDouble(key, v);
      case final String v:
        await prefs.setString(key, v);
      case final List<String> v:
        await prefs.setStringList(key, v);
      default:
        throw UnsupportedPrefsTypeError(value.runtimeType);
    }
    return value;
  }

  /// Read the current value, pass it through [updater] and store the result.
  ///
  /// [updater] receives `null` when nothing is stored yet, and may be
  /// asynchronous.
  static Future<void> update<T>(
    String key,
    FutureOr<T> Function(T?) updater,
  ) async {
    final value = await getOrNull<T>(key);
    final newValue = await updater(value);
    await set(key, newValue);
  }

  /// Like [update], but [updater] is given [defaultValue] instead of `null`
  /// when nothing is stored yet.
  ///
  /// Previously this cast a missing value to `T`, which always threw on the
  /// first call for a key.
  static Future<void> updateForcePipe<T>(
    String key,
    FutureOr<T> Function(T) updater, {
    required T defaultValue,
  }) async {
    final value = await getOrNull<T>(key);
    final newValue = await updater(value ?? defaultValue);
    await set(key, newValue);
  }
}
