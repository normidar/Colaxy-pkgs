import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:zaim_api/src/zaim_exception.dart';

/// The single HTTP + error-handling layer every endpoint class goes through.
///
/// Not exported from `package:zaim_api/zaim_api.dart`: it is an internal
/// implementation detail shared by the authenticated APIs (whose client signs
/// each request with OAuth 1.0a) and by the unauthenticated `/v2/*` master
/// data APIs (whose client is a plain [http.Client]).
class ZaimTransport {
  /// Wraps an [http.Client], optionally taking ownership of [ownedClient] so
  /// that [close] disposes it. [ownedClient] must be `null` when the caller
  /// injected its own client.
  ZaimTransport(this._client, {http.Client? ownedClient})
      : _ownedClient = ownedClient;

  /// The resource base URL for every Zaim endpoint. HTTPS only.
  static const String baseUrl = 'https://api.zaim.net';

  /// The parameter Zaim requires on every endpoint that declares it. Always
  /// sent automatically, never part of a public method signature.
  static const Map<String, String> mappingParameter = {'mapping': '1'};

  final http.Client _client;
  final http.Client? _ownedClient;

  /// Performs a `GET` and decodes the JSON object it returns.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
  }) =>
      _send(http.Request('GET', _uri(path, query)));

  /// Performs a `POST` with a form-encoded body and decodes the JSON object
  /// it returns.
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, String> fields,
  ) =>
      _send(http.Request('POST', _uri(path, const {}))..bodyFields = fields);

  /// Performs a `PUT` with a form-encoded body and decodes the JSON object it
  /// returns.
  Future<Map<String, dynamic>> put(
    String path,
    Map<String, String> fields,
  ) =>
      _send(http.Request('PUT', _uri(path, const {}))..bodyFields = fields);

  /// Performs a `DELETE` and decodes the JSON object it returns.
  ///
  /// Zaim's delete endpoints take their parameters in the URL, so the
  /// required `mapping=1` travels as a query parameter here rather than as a
  /// body field.
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String> query = const {},
  }) =>
      _send(http.Request('DELETE', _uri(path, query)));

  /// Closes the client this transport created itself. Injected clients are
  /// left alone: whoever created them owns them.
  void close() => _ownedClient?.close();

  Future<Map<String, dynamic>> _send(http.Request request) async {
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Uri _uri(String path, Map<String, String> query) {
    final uri = Uri.parse('$baseUrl$path');
    if (query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  static Map<String, dynamic> _decode(http.Response response) {
    // `http.Response.body` decodes with the charset from `Content-Type`,
    // which defaults to latin-1; Zaim answers in UTF-8, so decode the bytes
    // directly to keep Japanese category and place names intact.
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ZaimApiException.fromResponse(response.statusCode, body);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw ZaimApiException(
        statusCode: response.statusCode,
        message: 'Zaim returned a body that is not valid JSON.',
        body: body,
      );
    }
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw ZaimApiException(
      statusCode: response.statusCode,
      message: 'Zaim returned a JSON value that is not an object.',
      body: body,
    );
  }
}

/// Adapts any [http.Client] to the [http.BaseClient] the `oauth1` package
/// requires, without taking ownership of the wrapped client.
class BaseClientAdapter extends http.BaseClient {
  /// Wraps [_inner].
  BaseClientAdapter(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);
}

/// A [http.BaseClient] that converts non-2xx responses into
/// [ZaimApiException]s before the caller sees them.
///
/// Used for the OAuth token endpoints, which the `oauth1` package drives
/// itself: without this the package would surface a bare `StateError` for an
/// expired or unauthorized consumer key.
class ThrowingBaseClient extends http.BaseClient {
  /// Wraps [_inner].
  ThrowingBaseClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final streamed = await _inner.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ZaimApiException.fromResponse(
        response.statusCode,
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    }
    // The stream was drained to inspect the status, so hand back a fresh one.
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.bodyBytes.length,
      request: request,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
