// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_info_pod.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppInfoPod)
const appInfoPodProvider = AppInfoPodProvider._();

final class AppInfoPodProvider
    extends $AsyncNotifierProvider<AppInfoPod, PackageInfo> {
  const AppInfoPodProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appInfoPodProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appInfoPodHash();

  @$internal
  @override
  AppInfoPod create() => AppInfoPod();
}

String _$appInfoPodHash() => r'99c0b85bac954f269087e255c491238b50bc7b07';

abstract class _$AppInfoPod extends $AsyncNotifier<PackageInfo> {
  FutureOr<PackageInfo> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<PackageInfo>, PackageInfo>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<PackageInfo>, PackageInfo>,
        AsyncValue<PackageInfo>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
