// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prefs_bool_pod.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PrefsAliveBoolPod)
final prefsAliveBoolPodProvider = PrefsAliveBoolPodFamily._();

final class PrefsAliveBoolPodProvider
    extends $AsyncNotifierProvider<PrefsAliveBoolPod, bool?> {
  PrefsAliveBoolPodProvider._({
    required PrefsAliveBoolPodFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'prefsAliveBoolPodProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$prefsAliveBoolPodHash();

  @override
  String toString() {
    return r'prefsAliveBoolPodProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PrefsAliveBoolPod create() => PrefsAliveBoolPod();

  @override
  bool operator ==(Object other) {
    return other is PrefsAliveBoolPodProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$prefsAliveBoolPodHash() => r'cc776dcbdf639bd194ac552987ccb1173758c526';

final class PrefsAliveBoolPodFamily extends $Family
    with
        $ClassFamilyOverride<
          PrefsAliveBoolPod,
          AsyncValue<bool?>,
          bool?,
          FutureOr<bool?>,
          String
        > {
  PrefsAliveBoolPodFamily._()
    : super(
        retry: null,
        name: r'prefsAliveBoolPodProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  PrefsAliveBoolPodProvider call(String key) =>
      PrefsAliveBoolPodProvider._(argument: key, from: this);

  @override
  String toString() => r'prefsAliveBoolPodProvider';
}

abstract class _$PrefsAliveBoolPod extends $AsyncNotifier<bool?> {
  late final _$args = ref.$arg as String;
  String get key => _$args;

  FutureOr<bool?> build(String key);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool?>, bool?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool?>, bool?>,
              AsyncValue<bool?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
