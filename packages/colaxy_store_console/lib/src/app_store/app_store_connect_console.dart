import 'package:colaxy_store_console/src/app_store/app_store_api_key.dart';
import 'package:colaxy_store_console/src/app_store/app_store_connect_client.dart';
import 'package:colaxy_store_console/src/app_store/app_store_reviews_api.dart';
import 'package:http/http.dart' as http;

/// Entry point for one app on the App Store.
///
/// Unlike Google Play there is no handshake to perform — tokens are signed
/// locally — so this constructs synchronously.
///
/// ## Parameters
///
/// ### Required
/// - **`apiKey`**: The App Store Connect API key to authenticate with.
/// - **[appId]**: The app's App Store Connect resource ID. This is the
///   numeric ID from the App Store Connect URL (`/apps/6740000000/…`), not
///   the bundle ID and not the App Store listing ID.
///
/// ### Optional
/// - **`httpClient`**: Transport to use (default: a new client this object
///   owns and closes).
/// - **`baseUri`**: API root (default:
///   `https://api.appstoreconnect.apple.com/`).
///
/// ## Example
///
/// ```dart
/// final appStore = AppStoreConnectConsole(
///   apiKey: AppStoreApiKey.fromP8File(
///     keyId: 'ABCD123456',
///     issuerId: '69a6de70-....-1f2c3d4e5f60',
///     path: 'secrets/AuthKey_ABCD123456.p8',
///   ),
///   appId: '6740000000',
/// );
/// final page = await appStore.reviews.listPage();
/// appStore.close();
/// ```
class AppStoreConnectConsole {
  /// Creates a console for one App Store app.
  factory AppStoreConnectConsole({
    required AppStoreApiKey apiKey,
    required String appId,
    http.Client? httpClient,
    Uri? baseUri,
  }) => AppStoreConnectConsole.client(
    client: AppStoreConnectClient(
      apiKey: apiKey,
      httpClient: httpClient,
      baseUri: baseUri,
    ),
    appId: appId,
  );

  /// Creates a console around an existing [AppStoreConnectClient].
  ///
  /// Use this to share one transport — and so one cached token — between
  /// several apps on the same team.
  AppStoreConnectConsole.client({
    required AppStoreConnectClient client,
    required this.appId,
  }) : _client = client,
       reviews = AppStoreReviewsApi(client: client, appId: appId);

  /// The app's App Store Connect resource ID.
  final String appId;

  /// Reviews for this app.
  final AppStoreReviewsApi reviews;

  final AppStoreConnectClient _client;

  /// The underlying transport, for calls this package does not wrap yet.
  AppStoreConnectClient get client => _client;

  /// Releases the HTTP client.
  void close() => _client.close();
}
