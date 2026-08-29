import 'dart:convert';

import 'package:colaxy_store_console/src/core/retry_policy.dart';
import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_console_exception.dart';
import 'package:colaxy_store_console/src/core/store_console_log.dart';
import 'package:colaxy_store_console/src/google_play/google_api_error.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// Reads objects from the Cloud Storage bucket Google Play publishes reports
/// to.
///
/// Only two calls are needed — list by prefix, and download — so this is
/// written against the Cloud Storage JSON API directly rather than pulling in
/// a storage SDK. `googleapis`' storage library is deprecated in favour of
/// `google_cloud_storage`, and neither is worth a dependency for two GETs.
///
/// ## Parameters
///
/// ### Required
/// - **`authenticatedClient`**: From `PlayServiceAccount.authenticate` with
///   `storageReadScope`.
///
/// ### Optional
/// - **[baseUri]**: API root (default: `https://storage.googleapis.com/`).
/// - **[ownsClient]**: Whether [close] closes `authenticatedClient`
///   (default: `true`; pass `false` when several APIs share one).
/// - **[retryPolicy]**: When to retry (default: `RetryPolicy()`).
/// - **[onLog]**: Receives one line per retry and wait (default: `null`).
class PlayStorageClient {
  /// Creates a Cloud Storage client.
  PlayStorageClient({
    required http.Client authenticatedClient,
    Uri? baseUri,
    this.ownsClient = true,
    this.retryPolicy = const RetryPolicy(),
    this.onLog,
    @visibleForTesting Future<void> Function(Duration)? sleep,
  }) : _http = authenticatedClient,
       _sleep = sleep ?? _wait,
       baseUri = baseUri ?? Uri.https('storage.googleapis.com');

  /// Explains the usual causes of a `401`/`403` from this bucket.
  ///
  /// Worth being specific, because the obvious fixes do not work. The bucket
  /// belongs to Google, not to your Cloud project, so no amount of GCP IAM —
  /// Storage Admin, project Owner — grants access to it. Only Play Console
  /// does, and only at the account level.
  static const authHint =
      'This bucket is Google-owned, so GCP IAM roles do not reach it. Grant '
      'access in Play Console -> Users and permissions -> the service '
      "account -> the *Account permissions* tab -> 'View app information and "
      "download bulk reports'. Granting it on the Apps tab instead is the "
      'usual cause of this error. Changes can take up to 24 hours to reach '
      'the bucket. Also check the token carries '
      'PlayServiceAccount.storageReadScope.';

  /// API root every path is resolved against.
  final Uri baseUri;

  /// Whether [close] should close the client this object was given.
  ///
  /// `true` suits the common case of one API over one authenticated client.
  /// Pass `false` when several APIs share one — a single
  /// `authenticate(scopes: [reportingScope, storageReadScope])` call covers
  /// both Play statistics APIs, and letting the first `close()` shut it would
  /// break the second.
  ///
  /// `AppStoreConnectClient` decides this for itself, because it creates the
  /// client when it is not given one. Nothing here can: an authenticated
  /// client always comes from the caller.
  final bool ownsClient;

  /// When to retry a throttled or transiently failing request.
  final RetryPolicy retryPolicy;

  /// Receives one line per retry and wait.
  final StoreConsoleLog? onLog;

  final http.Client _http;
  final Future<void> Function(Duration) _sleep;

  static Future<void> _wait(Duration duration) =>
      Future<void>.delayed(duration);

  /// Every object name in [bucket] under [prefix], following pagination.
  ///
  /// Listing is the only way in. Asking for the bucket's own metadata, or
  /// listing the project's buckets, needs permissions Play never grants —
  /// the bucket is not in your project — so neither is attempted.
  Future<List<String>> list(String bucket, {required String prefix}) async {
    final names = <String>[];
    String? pageToken;

    do {
      final uri = baseUri.replace(
        path: '/storage/v1/b/$bucket/o',
        queryParameters: {
          'prefix': prefix,
          'pageToken': ?pageToken,
        },
      );
      final response = await _send(() => _http.get(uri));
      final body = _decode(response);

      final items = body['items'];
      if (items is List) {
        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          final name = item['name'];
          if (name is String) names.add(name);
        }
      }
      final next = body['nextPageToken'];
      pageToken = next is String && next.isNotEmpty ? next : null;
    } while (pageToken != null);

    names.sort();
    return names;
  }

  /// Downloads [objectName] from [bucket], or `null` if it does not exist.
  ///
  /// A missing object is `null` rather than an exception because the common
  /// reason is a month Google has not published, which is an answer.
  ///
  /// The object name is percent-encoded whole, slashes included: the JSON
  /// API takes it as one path segment, and leaving the slashes raw resolves
  /// to a different, non-existent endpoint.
  Future<List<int>?> download(String bucket, String objectName) async {
    final uri = baseUri.replace(
      path: '/storage/v1/b/$bucket/o/${Uri.encodeComponent(objectName)}',
      queryParameters: const {'alt': 'media'},
    );

    final response = await _send(() => _http.get(uri), allowNotFound: true);
    if (response.statusCode == 404) return null;
    return response.bodyBytes;
  }

  /// Closes the authenticated client, if this object owns it.
  void close() {
    if (ownsClient) _http.close();
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    bool allowNotFound = false,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      final response = await request();
      if (response.statusCode < 400) return response;
      if (allowNotFound && response.statusCode == 404) return response;

      final error = GoogleApiError.translate(response, authHint: authHint);
      final retryable =
          error is StoreRateLimitException ||
          retryPolicy.shouldRetry(
            attempt: attempt,
            statusCode: response.statusCode,
          );
      if (!retryable || attempt >= retryPolicy.maxAttempts) throw error;

      final wait = retryPolicy.backoffFor(attempt);
      onLog?.call(
        '${response.statusCode} from Cloud Storage; retrying in '
        '${wait.inMilliseconds}ms (attempt $attempt of '
        '${retryPolicy.maxAttempts})',
      );
      await _sleep(wait);
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StoreApiException(
        'Expected a JSON object from Cloud Storage, got '
        '${decoded.runtimeType}.',
        statusCode: response.statusCode,
        store: Store.googlePlay,
      );
    }
    return decoded;
  }
}
