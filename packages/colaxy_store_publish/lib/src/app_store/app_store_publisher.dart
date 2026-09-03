import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/app_info.dart';
import 'package:colaxy_store_publish/src/app_store/app_info_localizations_api.dart';
import 'package:colaxy_store_publish/src/app_store/app_infos_api.dart';
import 'package:colaxy_store_publish/src/app_store/app_screenshots_api.dart';
import 'package:colaxy_store_publish/src/app_store/app_store_builds_api.dart';
import 'package:colaxy_store_publish/src/app_store/app_store_version.dart';
import 'package:colaxy_store_publish/src/app_store/app_store_version_localizations_api.dart';
import 'package:colaxy_store_publish/src/app_store/app_store_versions_api.dart';
import 'package:colaxy_store_publish/src/app_store/asset_uploader.dart';
import 'package:colaxy_store_publish/src/app_store/beta_groups_api.dart';
import 'package:colaxy_store_publish/src/app_store/beta_testers_api.dart';
import 'package:colaxy_store_publish/src/app_store/review_submissions_api.dart';
import 'package:colaxy_store_publish/src/app_store/test_flight_api.dart';
import 'package:http/http.dart' as http;

/// The entry point for publishing to the App Store.
///
/// **There is no transaction here, and that is not an omission.** Google Play
/// gives you an edit to stage changes in and a `commit` to apply them; App
/// Store Connect has nothing equivalent, so every write below lands
/// immediately and a run that fails halfway leaves the store half-updated.
/// The closest thing to a rollback the API offers is deleting the whole
/// version.
///
/// This asymmetry is deliberately left visible rather than papered over with
/// a shared interface: code written against one that assumed the other would
/// be wrong about the thing that matters most.
///
/// **On credentials.** The App Store Connect key has to be a *team* key. An
/// individual key cannot reach several endpoints — `colaxy_store_console`
/// found the same thing on the sales reports.
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: An authenticated App Store Connect client.
/// - **[appId]**: The numeric app ID from the App Store Connect URL.
///
/// ### Optional
/// - **`uploader`**: Sends screenshot bytes (default: one this object owns).
/// - **[ownsClient]**: Whether [close] closes `client` (default: `true`).
/// - **[onLog]**: Receives one line per step (default: `null`).
///
/// ## Example
///
/// ```dart
/// final publisher = AppStorePublisher.authenticate(
///   apiKey: AppStoreApiKey.fromP8File(
///     keyId: keyId,
///     issuerId: issuerId,
///     path: 'secrets/AuthKey.p8',
///   ),
///   appId: '6740000000',
/// );
/// ```
class AppStorePublisher {
  /// Creates a publisher over an authenticated client.
  AppStorePublisher({
    required AppStoreConnectClient client,
    required this.appId,
    AssetUploader? uploader,
    this.ownsClient = true,
    this.onLog,
  }) : _client = client,
       _uploader =
           uploader ?? AssetUploader(retryPolicy: client.retryPolicy,
               onLog: onLog),
       _ownsUploader = uploader == null;

  /// Creates a publisher from an App Store Connect API key.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[apiKey]**: A **team** key. An individual key is rejected by
  ///   several endpoints.
  /// - **[appId]**: The numeric app ID.
  ///
  /// ### Optional
  /// - **[httpClient]**: Transport to share (default: one per client).
  /// - **[retryPolicy]**: When to retry (default: `RetryPolicy()`).
  /// - **[onLog]**: Receives one line per retry and step (default: `null`).
  factory AppStorePublisher.authenticate({
    required AppStoreApiKey apiKey,
    required String appId,
    http.Client? httpClient,
    RetryPolicy retryPolicy = const RetryPolicy(),
    StoreConsoleLog? onLog,
  }) => AppStorePublisher(
    client: AppStoreConnectClient(
      apiKey: apiKey,
      httpClient: httpClient,
      retryPolicy: retryPolicy,
      onLog: onLog,
    ),
    appId: appId,
    onLog: onLog,
  );

  /// The numeric app ID.
  final String appId;

  /// Whether [close] closes the client this object was given.
  final bool ownsClient;

  /// Receives one line per step.
  final StoreConsoleLog? onLog;

  final AppStoreConnectClient _client;
  final AssetUploader _uploader;
  final bool _ownsUploader;

  /// The app's versions.
  AppStoreVersionsApi get versions =>
      AppStoreVersionsApi(client: _client, appId: appId);

  /// The app's app-wide info records.
  AppInfosApi get appInfos => AppInfosApi(client: _client, appId: appId);

  /// The app's builds. Read-only as far as creating them goes.
  AppStoreBuildsApi get builds =>
      AppStoreBuildsApi(client: _client, appId: appId);

  /// The app's TestFlight groups.
  BetaGroupsApi get betaGroups =>
      BetaGroupsApi(client: _client, appId: appId);

  /// The account's TestFlight testers.
  BetaTestersApi get betaTesters => BetaTestersApi(client: _client);

  /// Getting a build to TestFlight groups, beta review included.
  TestFlightApi get testFlight =>
      TestFlightApi(builds: builds, groups: betaGroups, onLog: onLog);

  /// Submitting a version to App Store review.
  ///
  /// Nothing else in this package calls it: submitting is the one action a
  /// pipeline takes that a human cannot quietly undo.
  ReviewSubmissionsApi get reviewSubmissions =>
      ReviewSubmissionsApi(client: _client, appId: appId);

  /// Screenshots, which need an uploader as well as the API.
  AppScreenshotsApi get screenshots =>
      AppScreenshotsApi(client: _client, uploader: _uploader, onLog: onLog);

  /// The version-scoped localizations of [version].
  AppStoreVersionLocalizationsApi versionLocalizations(
    AppStoreVersion version,
  ) => AppStoreVersionLocalizationsApi(
    client: _client,
    versionId: version.id,
  );

  /// The app-wide localizations hanging off [info].
  AppInfoLocalizationsApi appInfoLocalizations(AppInfo info) =>
      AppInfoLocalizationsApi(client: _client, appInfoId: info.id);

  /// Closes the HTTP clients this object owns.
  void close() {
    if (ownsClient) _client.close();
    if (_ownsUploader) _uploader.close();
  }
}
