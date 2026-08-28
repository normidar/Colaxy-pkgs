import 'dart:convert';

import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_console_exception.dart';
import 'package:http/http.dart' as http;

/// Maps a Google JSON API error response onto this package's exceptions.
///
/// Every Google API this package talks to directly — Play Developer
/// Reporting and Cloud Storage — reports failures the same way, as
/// `{"error": {code, message, status}}`. Keeping the translation in one place
/// stops the two clients drifting into disagreeing about what a `403` means.
abstract final class GoogleApiError {
  /// Translates [response], which must be a failure.
  ///
  /// [authHint] is appended to authentication failures. Both callers have a
  /// different likely cause — the wrong OAuth scope, a service account never
  /// invited in Play Console — and Google's own message says neither.
  static StoreConsoleException translate(
    http.Response response, {
    String authHint = '',
  }) {
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
      // A load-balancer failure arrives as HTML. The status code still
      // identifies it, so the defaults stand.
    }

    // Google signals an exhausted quota as RESOURCE_EXHAUSTED, which can
    // arrive as 429 or as 403 depending on the API.
    if (status == 'RESOURCE_EXHAUSTED' || response.statusCode == 429) {
      return StoreRateLimitException(
        message,
        statusCode: response.statusCode,
        store: Store.googlePlay,
        code: status,
      );
    }
    if (response.statusCode == 401 ||
        (response.statusCode == 403 &&
            (status == null || status == 'PERMISSION_DENIED'))) {
      return StoreAuthException(
        authHint.isEmpty ? message : '$message. $authHint',
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
}
