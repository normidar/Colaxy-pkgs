import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records which builds of the app have run on this device.
///
/// Use it to decide whether a tutorial is worth showing — e.g. "only show the
/// what's-new tour to someone who has run an older build before".
class VersionRecorder {
  /// The key used to store recorded build numbers in SharedPreferences.
  static const key = 'tutorial_versions_recorded';

  /// Every build number recorded so far, oldest first.
  static Future<List<String>> recordedBuildNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? const [];
  }

  /// True when [checker] accepts *every* recorded build number.
  ///
  /// Vacuously true when nothing has been recorded yet.
  ///
  /// Note this inspects build numbers (`PackageInfo.buildNumber`), not
  /// versions — [recordVersion] is what writes them.
  static Future<bool> isRecordedVersionAnd({
    required bool Function(String buildNumber) checker,
  }) async {
    final versions = await recordedBuildNumbers();
    return versions.every(checker);
  }

  /// True when [checker] accepts *any* recorded build number.
  static Future<bool> isRecordedVersionOr({
    required bool Function(String buildNumber) checker,
  }) async {
    final versions = await recordedBuildNumbers();
    return versions.any(checker);
  }

  /// Records the build number the app is currently running.
  ///
  /// Call this once at startup. Repeated calls for the same build are no-ops.
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
