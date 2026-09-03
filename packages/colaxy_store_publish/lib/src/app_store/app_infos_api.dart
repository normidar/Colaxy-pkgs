import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/app_info.dart';

/// The app-wide info records of one app.
///
/// **An app has several of these, one per state**, and the app-wide metadata
/// — name, subtitle, privacy policy — is written through whichever one is
/// editable. Writing through a record in another state is reported to succeed
/// and change nothing visible.
///
/// That failure has no local symptom at all: the request returns `200`, the
/// publish reports success, and the store keeps the old name. It is the
/// Apple-side counterpart of the misspelled screenshot directory that
/// `MetadataCheck` catches on Android — except that nothing on disk can
/// reveal it, so it has to be prevented here.
///
/// **`/v1/apps/{id}/appInfos` accepts no filter parameters** (verified
/// against the 4.4.1 specification), so the state cannot be pushed to the
/// server the way it can for versions. Every record is fetched and sorted
/// through locally.
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: An authenticated App Store Connect client.
/// - **[appId]**: The numeric app ID.
///
/// ## Example
///
/// ```dart
/// final info = await api.editable();
/// ```
class AppInfosApi {
  /// Creates an app info client for one app.
  const AppInfosApi({
    required AppStoreConnectClient client,
    required this.appId,
  }) : _client = client;

  /// The numeric app ID.
  final String appId;

  final AppStoreConnectClient _client;

  /// Every app info record, in the order Apple returns them.
  Future<List<AppInfo>> list() async {
    final resources = await _client
        .resources('/v1/apps/$appId/appInfos', query: {'limit': 200})
        .toList();
    return [for (final json in resources) AppInfo.fromJson(json)];
  }

  /// The one record app-wide metadata can be written through.
  ///
  /// `null` when no record is in an editable state, which is the honest
  /// answer: there is nothing to write to, and picking the first record
  /// instead would write somewhere invisible.
  Future<AppInfo?> editable() async {
    for (final info in await list()) {
      if (info.isEditable) return info;
    }
    return null;
  }
}
