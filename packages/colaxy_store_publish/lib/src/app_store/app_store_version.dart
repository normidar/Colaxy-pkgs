import 'package:colaxy_store_publish/src/app_store/app_store_version_state.dart';
import 'package:meta/meta.dart';

/// One version of an app on the App Store.
///
/// The unit metadata hangs off: `description`, `keywords` and `whatsNew` all
/// belong to a version, not to the app. The app-wide half — name, subtitle,
/// privacy policy — lives on `AppInfo` instead, which is the split that makes
/// publishing to Apple two writes where Google Play needs one.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: Apple's identifier for the version.
///
/// ### Optional
/// - **[versionString]**: The marketing version, e.g. `1.4.0`.
/// - **[platform]**: `IOS`, `MAC_OS`, `TV_OS` or `VISION_OS`.
/// - **[appStoreState]**: Where it sits in the review cycle.
/// - **[appVersionState]**: The newer, *different* state enum.
/// - **[copyright]**: The copyright line.
/// - **[createdDate]**: When Apple created the version.
@immutable
class AppStoreVersion {
  /// Creates a version.
  const AppStoreVersion({
    required this.id,
    this.versionString,
    this.platform,
    this.appStoreState,
    this.appVersionState,
    this.copyright,
    this.createdDate,
  });

  /// Reads a version out of a JSON:API resource object.
  @internal
  factory AppStoreVersion.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    return AppStoreVersion(
      id: json['id'] as String? ?? '',
      versionString: attributes['versionString'] as String?,
      platform: attributes['platform'] as String?,
      appStoreState: AppStoreVersionState.byWireName(
        attributes['appStoreState'] as String? ?? '',
      ),
      appVersionState: AppVersionState.byWireName(
        attributes['appVersionState'] as String? ?? '',
      ),
      copyright: attributes['copyright'] as String?,
      createdDate: DateTime.tryParse(
        attributes['createdDate'] as String? ?? '',
      ),
    );
  }

  /// Apple's identifier for the version.
  final String id;

  /// The marketing version, e.g. `1.4.0`.
  final String? versionString;

  /// `IOS`, `MAC_OS`, `TV_OS` or `VISION_OS`.
  final String? platform;

  /// Where it sits in the review cycle.
  final AppStoreVersionState? appStoreState;

  /// The newer state enum, which is **not** the same set of values as
  /// [appStoreState].
  final AppVersionState? appVersionState;

  /// The copyright line.
  final String? copyright;

  /// When Apple created the version.
  final DateTime? createdDate;

  /// Whether metadata can be written to this version.
  ///
  /// Reads [appStoreState] rather than [appVersionState]: the former is what
  /// `filter[appStoreState]` accepts, so branching on it keeps the local
  /// decision and the server-side query consistent.
  bool get isEditable => appStoreState?.isEditable ?? false;

  @override
  String toString() =>
      'AppStoreVersion($id, ${versionString ?? '?'}, '
      '${appStoreState?.wireName ?? '?'})';
}
