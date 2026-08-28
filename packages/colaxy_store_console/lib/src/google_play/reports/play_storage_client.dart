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
/// - **[retryPolicy]**: When to retry (default: `RetryPolicy()`).
/// - **[onLog]**: Receives one line per retry and wait (default: `null`).
class PlayStorageClient {
  /// Creates a Cloud Storage client.
  PlayStorageClient({
    required http.Client authenticatedClient,
    Uri? baseUri,
    this.retryPolicy = const RetryPolicy(),
    this.onLog,
    @visibleForTesting Future<void> Function(Duration)? sleep,
  }) : _http = authenticatedClient,
       _sleep = sleep ?? _wait,
       baseUri = baseUri ?? Uri.https('storage.googleapis.com');

  /// Explains the usual causes of a `401`/`403` from this bucket.
  static const authHint =
      'Check that the service account is invited in Play Console under Users '
      'and permissions, and that the token was minted with '
      'PlayServiceAccount.storageReadScope.';

  /// API root every path is resolved against.
  final Uri baseUri;

  /// When to retry a throttled or transiently failing request.
  final RetryPolicy retryPolicy;

  /// Receives one line per retry and wait.
  final StoreConsoleLog? onLog;

  final http.Client _http;
  final Future<void> Function(Duration) _sleep;

  static Future<void> _wait(Duration duration) =>
      Future<void>.delayed(duration);

  /// Every object name in [bucket] under [prefix], following pagination.
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

  /// Closes the authenticated client.
  void close() => _http.close();

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
