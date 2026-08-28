import 'dart:convert';

import 'package:colaxy_store_console/src/app_store/app_store_api_key.dart';
import 'package:colaxy_store_console/src/app_store/app_store_token_provider.dart';
import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_console_exception.dart';
import 'package:http/http.dart' as http;

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
  }) : _tokens = AppStoreTokenProvider(apiKey),
       _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null,
       baseUri = baseUri ?? Uri.https('api.appstoreconnect.apple.com');

  /// API root every relative path is resolved against.
  final Uri baseUri;

  final AppStoreTokenProvider _tokens;
  final http.Client _http;
  final bool _ownsHttp;

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

  Map<String, String> _headers({bool withContentType = false}) => {
    'Authorization': 'Bearer ${_tokens.token()}',
    if (withContentType) 'Content-Type': 'application/json',
  };

  /// Runs [request], retrying once with a fresh token on `401`.
  ///
  /// A token can be accepted and then rejected within its own lifetime — the
  /// key is revoked, or Apple's clocks drift. Re-signing once turns that from
  /// a hard failure into a hiccup, and a second `401` still throws.
  Future<http.Response> _send(
    Future<http.Response> Function() request,
  ) async {
    var response = await request();
    if (response.statusCode == 401) {
      _tokens.invalidate();
      response = await request();
    }
    if (response.statusCode >= 400) throw _errorFor(response);
    return response;
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
