import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for recording and checking tutorial version history.
class VersionRecorder {
  /// The key used to store recorded versions in SharedPreferences.
  static const key = 'tutorial_versions_recorded';

  /// バージョン確認 全てtrueならtrue
  static Future<bool> isRecordedVersionAnd({
    required bool Function(String version) checker,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final versions = prefs.getStringList(key) ?? [];
    return versions.every(checker);
  }

  /// バージョン確認 どれか一つでもtrueならtrue
  static Future<bool> isRecordedVersionOr({
    required bool Function(String version) checker,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final versions = prefs.getStringList(key) ?? [];
    return versions.any(checker);
  }

  /// 今のバージョンを記録する
  static Future<void> recordVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();

    final versions = prefs.getStringList(key) ?? [];
    if (!versions.contains(info.buildNumber)) {
      versions.add(info.buildNumber);
      await prefs.setStringList(key, versions);
    }
  }
}
