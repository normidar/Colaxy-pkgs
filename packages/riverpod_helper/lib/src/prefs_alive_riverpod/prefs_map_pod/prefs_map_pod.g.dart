// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prefs_map_pod.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A keep-alive JSON map stored in SharedPreferences.
///
/// The auto-dispose family had a map pod but this one did not, so a map was the
/// only type you could not keep alive.

@ProviderFor(PrefsAliveMapPod)
final prefsAliveMapPodProvider = PrefsAliveMapPodFamily._();

/// A keep-alive JSON map stored in SharedPreferences.
///
/// The auto-dispose family had a map pod but this one did not, so a map was the
/// only type you could not keep alive.
final class PrefsAliveMapPodProvider
    extends $AsyncNotifierProvider<PrefsAliveMapPod, Map<String, dynamic>?> {
  /// A keep-alive JSON map stored in SharedPreferences.
  ///
  /// The auto-dispose family had a map pod but this one did not, so a map was the
  /// only type you could not keep alive.
  PrefsAliveMapPodProvider._({
    required PrefsAliveMapPodFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'prefsAliveMapPodProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$prefsAliveMapPodHash();

  @override
  String toString() {
    return r'prefsAliveMapPodProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PrefsAliveMapPod create() => PrefsAliveMapPod();

  @override
  bool operator ==(Object other) {
    return other is PrefsAliveMapPodProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$prefsAliveMapPodHash() => r'0499e1349dec6eef6ce67e69f72e98a86d24b863';

/// A keep-alive JSON map stored in SharedPreferences.
///
/// The auto-dispose family had a map pod but this one did not, so a map was the
/// only type you could not keep alive.

final class PrefsAliveMapPodFamily extends $Family
    with
        $ClassFamilyOverride<
          PrefsAliveMapPod,
          AsyncValue<Map<String, dynamic>?>,
          Map<String, dynamic>?,
          FutureOr<Map<String, dynamic>?>,
          String
        > {
  PrefsAliveMapPodFamily._()
    : super(
        retry: null,
        name: r'prefsAliveMapPodProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// A keep-alive JSON map stored in SharedPreferences.
  ///
  /// The auto-dispose family had a map pod but this one did not, so a map was the
  /// only type you could not keep alive.

  PrefsAliveMapPodProvider call(String key) =>
      PrefsAliveMapPodProvider._(argument: key, from: this);

  @override
  String toString() => r'prefsAliveMapPodProvider';
}

/// A keep-alive JSON map stored in SharedPreferences.
///
/// The auto-dispose family had a map pod but this one did not, so a map was the
/// only type you could not keep alive.

abstract class _$PrefsAliveMapPod
    extends $AsyncNotifier<Map<String, dynamic>?> {
  late final _$args = ref.$arg as String;
  String get key => _$args;

  FutureOr<Map<String, dynamic>?> build(String key);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<Map<String, dynamic>?>, Map<String, dynamic>?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Map<String, dynamic>?>,
                Map<String, dynamic>?
              >,
              AsyncValue<Map<String, dynamic>?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
