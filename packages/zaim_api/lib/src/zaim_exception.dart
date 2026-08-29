import 'dart:convert';

/// Thrown when the Zaim API answers with a non-success HTTP status, or with a
/// body that cannot be understood.
///
/// The documented Zaim errors are:
///
/// | HTTP | Message |
/// |---|---|
/// | 401 | This consumer key does not have a permission for the action. |
/// | 401 | User authentication was failed. |
/// | 404 | URL is not defined. |
/// | 400 | Parameters are not enough. |
/// | 400 | Insert action was failed. |
/// | 400 | Update action was failed. |
///
/// [message] carries the server's own text whenever the response contained
/// one, so callers can distinguish the two 401s and the three 400s.
///
/// ## Example
///
/// ```dart
/// try {
///   await client.money.createPayment(/* ... */);
/// } on ZaimAuthException catch (e) {
///   // 401 — token expired or the app lacks the "write" scope.
///   print(e.message);
/// } on ZaimApiException catch (e) {
///   print('${e.statusCode}: ${e.message}');
/// }
/// ```
class ZaimApiException implements Exception {
  /// Creates an exception describing a failed Zaim API call.
  const ZaimApiException({
    required this.statusCode,
    required this.message,
    required this.body,
  });

  /// Builds the right exception for a response, extracting the server's
  /// message from the body when it is JSON that carries one.
  ///
  /// Returns a [ZaimAuthException] for HTTP 401 and a plain
  /// [ZaimApiException] for every other status.
  factory ZaimApiException.fromResponse(int statusCode, String body) {
    final message = _extractMessage(body) ??
        'Zaim API request failed with status $statusCode.';
    if (statusCode == 401) {
      return ZaimAuthException(
        statusCode: statusCode,
        message: message,
        body: body,
      );
    }
    return ZaimApiException(
      statusCode: statusCode,
      message: message,
      body: body,
    );
  }

  /// The HTTP status code returned by Zaim.
  final int statusCode;

  /// The failure description: the server's `message` field when the response
  /// carried one, otherwise a generated summary of [statusCode].
  final String message;

  /// The raw, undecoded response body, kept for logging and debugging.
  final String body;

  @override
  String toString() => 'ZaimApiException($statusCode): $message';

  /// Pulls the human-readable error out of a Zaim error body.
  ///
  /// Zaim answers errors with a JSON object carrying a `message` string.
  // NOTE: the specification lists the message texts but not the exact error
  // envelope, so `error` is accepted as a fallback key and any non-JSON body
  // (the OAuth token endpoints answer in form encoding) yields `null`.
  static String? _extractMessage(String body) {
    if (body.trim().isEmpty) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    for (final key in const ['message', 'error']) {
      final value = decoded[key];
      if (value is String && value.isNotEmpty) return value;
      if (value is List && value.isNotEmpty) return value.join(' ');
    }
    return null;
  }
}

/// Thrown for HTTP 401 responses: the credentials are missing, expired, or
/// the app was not granted the scope the call needs.
///
/// Remember that a Zaim app registered without the *permanently accessible*
/// access level loses its permission 24 hours after the user authorized it;
/// a previously working token starting to raise this exception is the usual
/// symptom.
class ZaimAuthException extends ZaimApiException {
  /// Creates an authentication failure.
  const ZaimAuthException({
    required super.statusCode,
    required super.message,
    required super.body,
  });

  @override
  String toString() => 'ZaimAuthException($statusCode): $message';
}
