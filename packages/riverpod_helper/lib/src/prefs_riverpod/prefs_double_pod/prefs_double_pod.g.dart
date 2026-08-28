// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prefs_double_pod.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PrefsDoublePod)
final prefsDoublePodProvider = PrefsDoublePodFamily._();

final class PrefsDoublePodProvider
    extends $AsyncNotifierProvider<PrefsDoublePod, double?> {
  PrefsDoublePodProvider._({
    required PrefsDoublePodFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'prefsDoublePodProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$prefsDoublePodHash();

  @override
  String toString() {
    return r'prefsDoublePodProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PrefsDoublePod create() => PrefsDoublePod();

  @override
  bool operator ==(Object other) {
    return other is PrefsDoublePodProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$prefsDoublePodHash() => r'e7723bb108b5b280b07222b3b9ddab7e1230b712';

final class PrefsDoublePodFamily extends $Family
    with
        $ClassFamilyOverride<
          PrefsDoublePod,
          AsyncValue<double?>,
          double?,
          FutureOr<double?>,
          String
        > {
  PrefsDoublePodFamily._()
    : super(
        retry: null,
        name: r'prefsDoublePodProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PrefsDoublePodProvider call(String key) =>
      PrefsDoublePodProvider._(argument: key, from: this);

  @override
  String toString() => r'prefsDoublePodProvider';
}

abstract class _$PrefsDoublePod extends $AsyncNotifier<double?> {
  late final _$args = ref.$arg as String;
  String get key => _$args;

  FutureOr<double?> build(String key);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<double?>, double?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<double?>, double?>,
              AsyncValue<double?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
