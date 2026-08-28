import 'dart:convert';

import 'package:colaxy_store_console/src/core/retry_policy.dart';
import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_console_exception.dart';
import 'package:colaxy_store_console/src/core/store_console_log.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// Low-level transport for the Play Developer Reporting API.
///
/// This is hand-written because `googleapis` does not generate this API —
/// `playdeveloperreporting` is in neither `googleapis` nor `googleapis_beta`,
/// so unlike reviews there is nothing to delegate to.
///
/// It expects an already-authenticated client, since token handling belongs
/// to `googleapis_auth`. The scope must include
/// `PlayServiceAccount.reportingScope`: a token minted for the Android
/// Publisher scope is rejected here, and the rejection looks like a bad key.
///
/// ## Parameters
///
/// ### Required
/// - **`authenticatedClient`**: From `PlayServiceAccount.authenticate`.
///
/// ### Optional
/// - **[baseUri]**: API root (default:
///   `https://playdeveloperreporting.googleapis.com/`).
/// - **[retryPolicy]**: When to retry (default: `RetryPolicy()`).
/// - **[onLog]**: Receives one line per retry and wait (default: `null`).
///
/// ## Example
///
/// ```dart
/// final client = PlayReportingClient(
///   authenticatedClient: await account.authenticate(
///     scopes: [PlayServiceAccount.reportingScope],
///   ),
/// );
/// ```
class PlayReportingClient {
  /// Creates a client for the Play Developer Reporting API.
  PlayReportingClient({
    required http.Client authenticatedClient,
    Uri? baseUri,
    this.retryPolicy = const RetryPolicy(),
    this.onLog,
    @visibleForTesting Future<void> Function(Duration)? sleep,
  }) : _http = authenticatedClient,
       _sleep = sleep ?? _wait,
       baseUri = baseUri ?? Uri.https('playdeveloperreporting.googleapis.com');

  /// API version prefix every path is built on.
  static const apiVersion = 'v1beta1';

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

  /// GETs [path] under the API version prefix.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    final uri = _uri(path, query);
    final response = await _send(() => _http.get(uri));
    return _decode(response);
  }

  /// POSTs [body] as JSON to [path] under the API version prefix.
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = _uri(path, const {});
    final response = await _send(
      () => _http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  /// Closes the authenticated client.
  void close() => _http.close();

  Uri _uri(String path, Map<String, Object?> query) {
    final trimmed = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.replace(
      path: '/$apiVersion/$trimmed',
      queryParameters: query.isEmpty ? null : _encode(query),
    );
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    var attempt = 0;
    while (true) {
      attempt++;
      final response = await request();
      if (response.statusCode < 400) return response;

      final error = _errorFor(response);
      // Google reports an exhausted quota as RESOURCE_EXHAUSTED, which can
      // arrive as 429 or as 403; the translated type is the reliable signal.
      final retryable =
          error is StoreRateLimitException ||
          retryPolicy.shouldRetry(
            attempt: attempt,
            statusCode: response.statusCode,
          );
      if (!retryable || attempt >= retryPolicy.maxAttempts) throw error;

      final wait = retryPolicy.backoffFor(attempt);
      onLog?.call(
        '${response.statusCode} from Play Developer Reporting; retrying in '
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
        'Expected a JSON object from Play Developer Reporting, got '
        '${decoded.runtimeType}.',
        statusCode: response.statusCode,
        store: Store.googlePlay,
      );
    }
    return decoded;
  }

  /// Maps an error response onto the exception hierarchy.
  ///
  /// Google answers `{"error": {code, message, status, details}}`, but not
  /// always — a load-balancer failure arrives as HTML. Parsing is best-effort
  /// and a body that will not parse still yields a typed exception.
  StoreConsoleException _errorFor(http.Response response) {
    String? status;
    var message = 'Request failed';

    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final error = body['error'];
        if (error is Map<String, dynamic>) {
          message = error['message'] as String? ?? message;
          status = error['status'] as String?;
        }
      }
    } on FormatException {
      // Leave the defaults; the status code still identifies the failure.
    }

    if (status == 'RESOURCE_EXHAUSTED' || response.statusCode == 429) {
      return StoreRateLimitException(
        message,
        statusCode: response.statusCode,
        store: Store.googlePlay,
        code: status,
      );
    }
    if (response.statusCode == 401 ||
        (response.statusCode == 403 && status == 'PERMISSION_DENIED')) {
      return StoreAuthException(
        '$message. Check that the service account is invited in Play Console '
        'with "View app information", and that the token was minted with '
        'PlayServiceAccount.reportingScope — the Android Publisher scope does '
        'not cover this API.',
        store: Store.googlePlay,
      );
    }
    return StoreApiException(
      message,
      statusCode: response.statusCode,
      store: Store.googlePlay,
      code: status,
    );
  }

  static Map<String, String> _encode(Map<String, Object?> query) {
    final encoded = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      encoded[entry.key] = '$value';
    }
    return encoded;
  }
}
