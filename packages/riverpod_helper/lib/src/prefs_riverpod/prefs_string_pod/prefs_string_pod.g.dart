// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prefs_string_pod.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PrefsStringPod)
final prefsStringPodProvider = PrefsStringPodFamily._();

final class PrefsStringPodProvider
    extends $AsyncNotifierProvider<PrefsStringPod, String?> {
  PrefsStringPodProvider._({
    required PrefsStringPodFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'prefsStringPodProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$prefsStringPodHash();

  @override
  String toString() {
    return r'prefsStringPodProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PrefsStringPod create() => PrefsStringPod();

  @override
  bool operator ==(Object other) {
    return other is PrefsStringPodProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$prefsStringPodHash() => r'f6f85f04947d418e4b42d2769b0c9654d89a9bd2';

final class PrefsStringPodFamily extends $Family
    with
        $ClassFamilyOverride<
          PrefsStringPod,
          AsyncValue<String?>,
          String?,
          FutureOr<String?>,
          String
        > {
  PrefsStringPodFamily._()
    : super(
        retry: null,
        name: r'prefsStringPodProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PrefsStringPodProvider call(String key) =>
      PrefsStringPodProvider._(argument: key, from: this);

  @override
  String toString() => r'prefsStringPodProvider';
}

abstract class _$PrefsStringPod extends $AsyncNotifier<String?> {
  late final _$args = ref.$arg as String;
  String get key => _$args;

  FutureOr<String?> build(String key);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
