import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/app_store_version.dart';
import 'package:colaxy_store_publish/src/app_store/app_store_version_state.dart';

/// The App Store versions of one app.
///
/// Metadata is written to a version, so finding the right one is the first
/// step of every Apple publish — and the one with no equivalent on Google
/// Play, where an edit is opened rather than found.
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: An authenticated App Store Connect client.
/// - **[appId]**: The numeric app ID from the App Store Connect URL.
///
/// ## Example
///
/// ```dart
/// final version = await api.editable();
/// ```
class AppStoreVersionsApi {
  /// Creates a versions client for one app.
  const AppStoreVersionsApi({
    required AppStoreConnectClient client,
    required this.appId,
  }) : _client = client;

  /// The numeric app ID.
  final String appId;

  final AppStoreConnectClient _client;

  /// Every version of the app, newest first as Apple returns them.
  ///
  /// ## Parameters
  ///
  /// ### Optional
  /// - **[state]**: Ask Apple for one state only (default: `null`, all of
  ///   them). Filtering server-side saves paging through a long history.
  /// - **[platform]**: `IOS`, `MAC_OS`, `TV_OS` or `VISION_OS`
  ///   (default: `null`).
  Future<List<AppStoreVersion>> list({
    AppStoreVersionState? state,
    String? platform,
  }) async {
    final resources = await _client
        .resources(
          '/v1/apps/$appId/appStoreVersions',
          query: {
            'filter[appStoreState]': state?.wireName,
            'filter[platform]': platform,
            'limit': 200,
          },
        )
        .toList();
    return [for (final json in resources) AppStoreVersion.fromJson(json)];
  }

  /// The one version metadata can be written to, or `null` if there is none.
  ///
  /// Asks Apple for `PREPARE_FOR_SUBMISSION` directly rather than listing
  /// everything and sorting here: the filter is supported on this endpoint
  /// (unlike `appInfos`, which supports none at all), so the store does the
  /// work and the answer cannot drift from what the store thinks.
  ///
  /// `null` means there is no editable version — usually because the last
  /// one shipped and no new version has been created yet. Creating one is
  /// deliberately not automatic: a new version is a release decision.
  ///
  /// ## Parameters
  ///
  /// ### Optional
  /// - **[platform]**: Narrow to one platform (default: `null`).
  Future<AppStoreVersion?> editable({String? platform}) async {
    final versions = await list(
      state: AppStoreVersionState.prepareForSubmission,
      platform: platform,
    );
    return versions.isEmpty ? null : versions.first;
  }
}
