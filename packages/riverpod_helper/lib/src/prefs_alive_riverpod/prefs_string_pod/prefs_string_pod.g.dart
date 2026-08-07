// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prefs_string_pod.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PrefsAliveStringPod)
final prefsAliveStringPodProvider = PrefsAliveStringPodFamily._();

final class PrefsAliveStringPodProvider
    extends $AsyncNotifierProvider<PrefsAliveStringPod, String?> {
  PrefsAliveStringPodProvider._({
    required PrefsAliveStringPodFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'prefsAliveStringPodProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$prefsAliveStringPodHash();

  @override
  String toString() {
    return r'prefsAliveStringPodProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PrefsAliveStringPod create() => PrefsAliveStringPod();

  @override
  bool operator ==(Object other) {
    return other is PrefsAliveStringPodProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$prefsAliveStringPodHash() =>
    r'5837b57358c0d5c87e6bd95a7fa9c1efb5719a96';

final class PrefsAliveStringPodFamily extends $Family
    with
        $ClassFamilyOverride<
          PrefsAliveStringPod,
          AsyncValue<String?>,
          String?,
          FutureOr<String?>,
          String
        > {
  PrefsAliveStringPodFamily._()
    : super(
        retry: null,
        name: r'prefsAliveStringPodProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  PrefsAliveStringPodProvider call(String key) =>
      PrefsAliveStringPodProvider._(argument: key, from: this);

  @override
  String toString() => r'prefsAliveStringPodProvider';
}

abstract class _$PrefsAliveStringPod extends $AsyncNotifier<String?> {
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
