import 'package:colaxy_store_console/src/google_play/play_reviews_api.dart';
import 'package:colaxy_store_console/src/google_play/play_service_account.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:http/http.dart' as http;

/// Entry point for one app on Google Play.
///
/// Authenticating costs a token exchange, so build this once with
/// [GooglePlayConsole.connect] and keep it for the run rather than
/// reconnecting per call.
///
/// ## Parameters
///
/// ### Required
/// - **[packageName]**: The app's application ID, e.g. `com.example.app`.
/// - **[reviews]**: The reviews client, already authenticated.
///
/// ## Example
///
/// ```dart
/// final play = await GooglePlayConsole.connect(
///   account: PlayServiceAccount.fromFile('secrets/play-api.json'),
///   packageName: 'com.example.app',
/// );
/// final page = await play.reviews.listPage();
/// play.close();
/// ```
class GooglePlayConsole {
  /// Creates a console around an already-built reviews client.
  ///
  /// Prefer [GooglePlayConsole.connect]; this exists so a test can supply a
  /// stub.
  GooglePlayConsole({required this.packageName, required this.reviews});

  /// The app's application ID.
  final String packageName;

  /// Reviews for this app.
  final PlayReviewsApi reviews;

  /// Authenticates [account] and returns a console for [packageName].
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[account]**: The service account to authenticate as.
  /// - **[packageName]**: The app's application ID.
  ///
  /// ### Optional
  /// - **[baseClient]**: Transport the authenticated client wraps
  ///   (default: `null`, letting `googleapis_auth` create one).
  static Future<GooglePlayConsole> connect({
    required PlayServiceAccount account,
    required String packageName,
    http.Client? baseClient,
  }) async {
    final client = await account.authenticate(baseClient: baseClient);
    return GooglePlayConsole(
      packageName: packageName,
      reviews: PlayReviewsApi(
        api: play.AndroidPublisherApi(client),
        packageName: packageName,
        httpClient: client,
      ),
    );
  }

  /// Releases the authenticated HTTP client.
  void close() => reviews.close();
}
