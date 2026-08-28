// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prefs_double_pod.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PrefsAliveDoublePod)
final prefsAliveDoublePodProvider = PrefsAliveDoublePodFamily._();

final class PrefsAliveDoublePodProvider
    extends $AsyncNotifierProvider<PrefsAliveDoublePod, double?> {
  PrefsAliveDoublePodProvider._({
    required PrefsAliveDoublePodFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'prefsAliveDoublePodProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$prefsAliveDoublePodHash();

  @override
  String toString() {
    return r'prefsAliveDoublePodProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PrefsAliveDoublePod create() => PrefsAliveDoublePod();

  @override
  bool operator ==(Object other) {
    return other is PrefsAliveDoublePodProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$prefsAliveDoublePodHash() =>
    r'7d2259168fb53efd7e2c6ea2f651b9c52b5d85cc';

final class PrefsAliveDoublePodFamily extends $Family
    with
        $ClassFamilyOverride<
          PrefsAliveDoublePod,
          AsyncValue<double?>,
          double?,
          FutureOr<double?>,
          String
        > {
  PrefsAliveDoublePodFamily._()
    : super(
        retry: null,
        name: r'prefsAliveDoublePodProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  PrefsAliveDoublePodProvider call(String key) =>
      PrefsAliveDoublePodProvider._(argument: key, from: this);

  @override
  String toString() => r'prefsAliveDoublePodProvider';
}

abstract class _$PrefsAliveDoublePod extends $AsyncNotifier<double?> {
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
