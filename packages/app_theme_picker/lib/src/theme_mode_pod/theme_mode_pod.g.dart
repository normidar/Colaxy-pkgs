// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode_pod.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ThemeModePod)
final themeModePodProvider = ThemeModePodProvider._();

final class ThemeModePodProvider
    extends $AsyncNotifierProvider<ThemeModePod, ThemeMode> {
  ThemeModePodProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModePodProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModePodHash();

  @$internal
  @override
  ThemeModePod create() => ThemeModePod();
}

String _$themeModePodHash() => r'5366ade248562de667a485a9405b3ae1d5a52d85';

abstract class _$ThemeModePod extends $AsyncNotifier<ThemeMode> {
  FutureOr<ThemeMode> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThemeMode>, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThemeMode>, ThemeMode>,
              AsyncValue<ThemeMode>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
