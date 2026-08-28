import 'package:colaxy_store_console/src/app_store/app_store_api_key.dart';
import 'package:colaxy_store_console/src/app_store/app_store_connect_console.dart';
import 'package:colaxy_store_console/src/core/retry_policy.dart';
import 'package:colaxy_store_console/src/core/store_console_log.dart';
import 'package:colaxy_store_console/src/core/store_reviews_api.dart';
import 'package:colaxy_store_console/src/google_play/google_play_console.dart';
import 'package:colaxy_store_console/src/google_play/play_service_account.dart';
import 'package:colaxy_store_console/src/merged_reviews_api.dart';
import 'package:http/http.dart' as http;

/// One app across both stores.
///
/// This is the type most callers want: [reviews] reads from every store that
/// was configured, and each result carries the `Store` it came from. Either
/// store can be left out, so the same code works for an Android-only or
/// iOS-only app.
///
/// ## Parameters
///
/// ### Optional
/// - **[googlePlay]**: The Google Play side (default: `null`).
/// - **[appStore]**: The App Store side (default: `null`).
///
/// At least one must be given.
///
/// ## Example
///
/// ```dart
/// final console = await StoreConsole.connect(
///   playAccount: PlayServiceAccount.fromFile('secrets/play-api.json'),
///   packageName: 'com.example.app',
///   appStoreKey: AppStoreApiKey.fromP8File(
///     keyId: 'ABCD123456',
///     issuerId: '69a6de70-....-1f2c3d4e5f60',
///     path: 'secrets/AuthKey_ABCD123456.p8',
///   ),
///   appId: '6740000000',
/// );
///
/// const unanswered = ReviewQuery(ratings: {1, 2}, hasReply: false);
/// await for (final review in console.reviews.list(unanswered)) {
///   print('${review.store.displayName} ${review.rating}★ ${review.body}');
/// }
///
/// console.close();
/// ```
class StoreConsole {
  /// Creates a console over already-built per-store consoles.
  StoreConsole({this.googlePlay, this.appStore})
    : assert(
        googlePlay != null || appStore != null,
        'StoreConsole needs at least one of googlePlay or appStore',
      ),
      reviews = MergedReviewsApi([
        if (googlePlay != null) googlePlay.reviews,
        if (appStore != null) appStore.reviews,
      ]);

  /// The Google Play side, or `null` if not configured.
  final GooglePlayConsole? googlePlay;

  /// The App Store side, or `null` if not configured.
  final AppStoreConnectConsole? appStore;

  /// Reviews across every configured store.
  final StoreReviewsApi reviews;

  /// Connects to whichever stores it is given credentials for.
  ///
  /// A store is included when *both* of its arguments are present:
  /// [playAccount] with [packageName], and [appStoreKey] with [appId]. Pass
  /// only one pair for a single-platform app.
  ///
  /// ## Parameters
  ///
  /// ### Optional
  /// - **[playAccount]** / **[packageName]**: Google Play credentials and
  ///   application ID (default: `null`).
  /// - **[appStoreKey]** / **[appId]**: App Store Connect key and app
  ///   resource ID (default: `null`).
  /// - **[httpClient]**: Transport both sides use (default: each store
  ///   creates and owns its own).
  /// - **`retryPolicy`**: When to retry a throttled or transiently failing
  ///   request (default: `RetryPolicy()`, three attempts).
  /// - **`onLog`**: Receives one line per retry and wait (default: `null`).
  ///
  /// Throws [ArgumentError] if neither pair is complete — otherwise a typo in
  /// one argument would silently produce a console that reads nothing.
  static Future<StoreConsole> connect({
    PlayServiceAccount? playAccount,
    String? packageName,
    AppStoreApiKey? appStoreKey,
    String? appId,
    http.Client? httpClient,
    RetryPolicy retryPolicy = const RetryPolicy(),
    StoreConsoleLog? onLog,
  }) async {
    final wantsPlay = playAccount != null && packageName != null;
    final wantsAppStore = appStoreKey != null && appId != null;
    if (!wantsPlay && !wantsAppStore) {
      throw ArgumentError(
        'StoreConsole.connect needs a complete pair: playAccount with '
        'packageName, or appStoreKey with appId.',
      );
    }

    return StoreConsole(
      googlePlay: wantsPlay
          ? await GooglePlayConsole.connect(
              account: playAccount,
              packageName: packageName,
              baseClient: httpClient,
              retryPolicy: retryPolicy,
              onLog: onLog,
            )
          : null,
      appStore: wantsAppStore
          ? AppStoreConnectConsole(
              apiKey: appStoreKey,
              appId: appId,
              httpClient: httpClient,
              retryPolicy: retryPolicy,
              onLog: onLog,
            )
          : null,
    );
  }

  /// Releases every underlying HTTP client.
  void close() {
    googlePlay?.close();
    appStore?.close();
  }
}
