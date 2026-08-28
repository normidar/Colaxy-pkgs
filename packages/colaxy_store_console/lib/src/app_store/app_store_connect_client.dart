import 'dart:convert';

import 'package:colaxy_store_console/src/app_store/app_store_api_key.dart';
import 'package:colaxy_store_console/src/app_store/app_store_token_provider.dart';
import 'package:colaxy_store_console/src/app_store/json_api_page.dart';
import 'package:colaxy_store_console/src/core/retry_policy.dart';
import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_console_exception.dart';
import 'package:colaxy_store_console/src/core/store_console_log.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// Low-level transport for the App Store Connect REST API.
///
/// Everything Apple-side goes through here: it attaches the bearer token,
/// decodes JSON:API envelopes, and turns error responses into the
/// [StoreConsoleException] hierarchy. It knows nothing about reviews, so the
/// statistics clients can sit on top of the same object.
///
/// ## Parameters
///
/// ### Required
/// - **`apiKey`**: The App Store Connect API key to authenticate with.
///
/// ### Optional
/// - **`httpClient`**: Transport to use (default: a new [http.Client] this
///   object owns and closes). Pass one in to share a connection pool, or to
///   inject a mock in tests.
/// - **[baseUri]**: API root (default:
///   `https://api.appstoreconnect.apple.com/`). Point it at
///   `api.enterprise.developer.apple.com` for a custom app account.
/// - **[retryPolicy]**: When to retry a throttled or transiently failing
///   request (default: `RetryPolicy()`, three attempts).
/// - **[onLog]**: Receives one line per retry and wait (default: `null`,
///   logging nothing).
///
/// ## Example
///
/// ```dart
/// final client = AppStoreConnectClient(apiKey: key);
/// final json = await client.getJson('/v1/apps/6740000000');
/// client.close();
/// ```
class AppStoreConnectClient {
  /// Creates a client for the App Store Connect API.
  AppStoreConnectClient({
    required AppStoreApiKey apiKey,
    http.Client? httpClient,
    Uri? baseUri,
    this.retryPolicy = const RetryPolicy(),
    this.onLog,
    @visibleForTesting Future<void> Function(Duration)? sleep,
  }) : _tokens = AppStoreTokenProvider(apiKey),
       _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null,
       _sleep = sleep ?? _wait,
       baseUri = baseUri ?? Uri.https('api.appstoreconnect.apple.com');

  /// API root every relative path is resolved against.
  final Uri baseUri;

  /// When to retry a throttled or transiently failing request.
  final RetryPolicy retryPolicy;

  /// Receives one line per retry and wait.
  final StoreConsoleLog? onLog;

  final AppStoreTokenProvider _tokens;
  final http.Client _http;
  final bool _ownsHttp;
  final Future<void> Function(Duration) _sleep;

  static Future<void> _wait(Duration duration) =>
      Future<void>.delayed(duration);

  /// GETs [path] with [query] and returns the decoded JSON body.
  ///
  /// A query value of `null` is dropped, and a list value is joined with
  /// commas the way JSON:API expects, so callers can build filters without
  /// pruning empties first.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    final uri = baseUri.replace(path: path, queryParameters: _encode(query));
    return getUri(uri);
  }

  /// GETs an absolute [uri] and returns the decoded JSON body.
  ///
  /// Paging uses this: Apple hands back a fully-formed `links.next` URL, and
  /// re-deriving the query from it would only risk dropping a parameter.
  Future<Map<String, dynamic>> getUri(Uri uri) async {
    final response = await _send(() => _http.get(uri, headers: _headers()));
    return _decode(response);
  }

  /// GETs [path] with [query] and returns the raw response body.
  ///
  /// Reports are not JSON: Apple serves them as gzipped TSV, and gzip is not
  /// text at all. [accept] sets the `Accept` header — pass
  /// `application/a-gzip` for reports, which is the type Apple documents.
  ///
  /// Errors still arrive as JSON and are still mapped, so a failure throws the
  /// same exceptions as everywhere else rather than returning bad bytes.
  Future<List<int>> getBytes(
    String path, {
    Map<String, Object?> query = const {},
    String? accept,
  }) async {
    final uri = baseUri.replace(path: path, queryParameters: _encode(query));
    final response = await _send(
      () => _http.get(uri, headers: _headers(accept: accept)),
    );
    return response.bodyBytes;
  }

  /// GETs [path] with [query] as a JSON:API collection page.
  ///
  /// Prefer this over [getJson] for list endpoints: it pulls apart the
  /// envelope Apple wraps every collection in, so each API does not have to
  /// re-implement `links.next` and `meta.paging.total`.
  Future<JsonApiPage> getPage(
    String path, {
    Map<String, Object?> query = const {},
  }) async => JsonApiPage(await getJson(path, query: query));

  /// GETs the absolute [uri] of a page, typically a previous `links.next`.
  Future<JsonApiPage> getPageAt(Uri uri) async =>
      JsonApiPage(await getUri(uri));

  /// Every page of [path], following `links.next` until it stops.
  ///
  /// Pages are fetched lazily, so a caller that stops consuming stops the
  /// requests too.
  Stream<JsonApiPage> pages(
    String path, {
    Map<String, Object?> query = const {},
  }) async* {
    var page = await getPage(path, query: query);
    while (true) {
      yield page;
      final next = page.nextCursor;
      if (next == null) return;
      page = await getPageAt(Uri.parse(next));
    }
  }

  /// Every resource across every page of [path].
  ///
  /// Use [pages] instead when you need each response's `included` array,
  /// which this flattening drops.
  Stream<Map<String, dynamic>> resources(
    String path, {
    Map<String, Object?> query = const {},
  }) => pages(
    path,
    query: query,
  ).asyncExpand((page) => Stream.fromIterable(page.data));

  /// POSTs [body] as JSON to [path] and returns the decoded JSON body.
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = baseUri.replace(path: path);
    final response = await _send(
      () => _http.post(
        uri,
        headers: _headers(withContentType: true),
        body: jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  /// PATCHes [body] as JSON to [path] and returns the decoded JSON body.
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = baseUri.replace(path: path);
    final response = await _send(
      () => _http.patch(
        uri,
        headers: _headers(withContentType: true),
        body: jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  /// DELETEs [path].
  ///
  /// Apple answers `204` with an empty body, so nothing is decoded.
  Future<void> delete(String path) async {
    final uri = baseUri.replace(path: path);
    await _send(() => _http.delete(uri, headers: _headers()));
  }

  /// Closes the HTTP client, if this object owns it.
  ///
  /// A client passed to the constructor is left alone: its owner may still be
  /// using it.
  void close() {
    if (_ownsHttp) _http.close();
  }

  Map<String, String> _headers({
    bool withContentType = false,
    String? accept,
  }) => {
    'Authorization': 'Bearer ${_tokens.token()}',
    if (withContentType) 'Content-Type': 'application/json',
    'Accept': ?accept,
  };

  /// Runs [request], re-signing once on `401` and backing off per
  /// [retryPolicy] on throttling and transient server errors.
  ///
  /// The `401` path is separate from the retry policy on purpose. A token can
  /// be accepted and then rejected within its own lifetime — the key is
  /// revoked, or Apple's clocks drift — and the fix is a fresh signature, not
  /// a wait. It is allowed exactly once, so a genuinely bad key still fails
  /// fast instead of looping.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    var attempt = 0;
    var reSigned = false;

    while (true) {
      attempt++;
      final response = await request();
      final status = response.statusCode;

      if (status < 400) return response;

      if (status == 401 && !reSigned) {
        reSigned = true;
        _tokens.invalidate();
        onLog?.call('401 from App Store Connect; re-signing the token');
        continue;
      }

      if (!retryPolicy.shouldRetry(attempt: attempt, statusCode: status)) {
        throw _errorFor(response);
      }

      final wait = retryPolicy.backoffFor(
        attempt,
        retryAfter: _retryAfter(response),
      );
      onLog?.call(
        '$status from App Store Connect; retrying in '
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
        'Expected a JSON object from App Store Connect, got '
        '${decoded.runtimeType}.',
        statusCode: response.statusCode,
        store: Store.appStore,
      );
    }
    return decoded;
  }

  /// Maps an error response onto the exception hierarchy.
  ///
  /// Apple returns `{"errors": [{status, code, title, detail}, …]}`, but not
  /// on every failure — a gateway error comes back as HTML. Parsing is
  /// therefore best-effort, and a body that will not parse still yields a
  /// typed exception carrying the status.
  StoreConsoleException _errorFor(http.Response response) {
    String? code;
    var title = 'Request failed';
    String? detail;

    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final errors = body['errors'];
        if (errors is List && errors.isNotEmpty) {
          final first = errors.first;
          if (first is Map<String, dynamic>) {
            code = first['code'] as String?;
            title = first['title'] as String? ?? title;
            detail = first['detail'] as String?;
          }
          if (errors.length > 1) {
            detail = '${detail ?? ''}\n(+${errors.length - 1} more errors)';
          }
        }
      }
    } on FormatException {
      detail = response.body.isEmpty
          ? null
          : response.body.substring(0, response.body.length.clamp(0, 500));
    }

    if (response.statusCode == 429) {
      return StoreRateLimitException(
        title,
        statusCode: 429,
        store: Store.appStore,
        code: code,
        detail: detail,
        retryAfter: _retryAfter(response),
      );
    }
    if (response.statusCode == 401) {
      return StoreAuthException(
        '$title. Check the key ID, issuer ID and .p8 key.',
        store: Store.appStore,
      );
    }
    return StoreApiException(
      title,
      statusCode: response.statusCode,
      store: Store.appStore,
      code: code,
      detail: detail,
    );
  }

  static Duration? _retryAfter(http.Response response) {
    final header = response.headers['retry-after'];
    if (header == null) return null;
    final seconds = int.tryParse(header);
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static Map<String, String> _encode(Map<String, Object?> query) {
    final encoded = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is Iterable) {
        if (value.isEmpty) continue;
        encoded[entry.key] = value.join(',');
      } else {
        encoded[entry.key] = '$value';
      }
    }
    return encoded;
  }
}
