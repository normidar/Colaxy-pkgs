import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:package_info_plus/package_info_plus.dart' show PackageInfo;

part 'app_info_pod.g.dart';

@Riverpod(keepAlive: true)
class AppInfoPod extends _$AppInfoPod {
  @override
  Future<PackageInfo> build() {
    return PackageInfo.fromPlatform();
  }
}
