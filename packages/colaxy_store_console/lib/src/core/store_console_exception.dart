import 'package:colaxy_store_console/src/core/store.dart';

/// Base class for every failure this package raises.
///
/// Both consoles report errors in their own shape — Google through
/// `googleapis`' `DetailedApiRequestError`, Apple through a JSON:API `errors`
/// array. They are normalised into this hierarchy so a caller can handle
/// "the store rejected us" without branching on which store it was.
///
/// ## Parameters
///
/// ### Required
/// - **[message]**: What went wrong, in one line.
///
/// ### Optional
/// - **[store]**: Which store produced the failure (default: `null`, for
///   errors raised before a store was picked, such as bad credentials).
class StoreConsoleException implements Exception {
  /// Creates a store console failure.
  const StoreConsoleException(this.message, {this.store});

  /// What went wrong, in one line.
  final String message;

  /// Which store produced the failure, when it is known.
  final Store? store;

  /// The name used to introduce this failure in [toString].
  ///
  /// Subclasses override this rather than `runtimeType`, which the analyzer
  /// rejects because minified builds do not preserve type names.
  String get label => 'StoreConsoleException';

  @override
  String toString() {
    final prefix = store == null ? '' : '[${store!.displayName}] ';
    return '$prefix$label: $message';
  }
}

/// The credentials were missing, malformed, or rejected by the store.
///
/// Raised for a `.p8` key that will not parse, a service-account JSON that is
/// not a service account, and for `401` responses.
class StoreAuthException extends StoreConsoleException {
  /// Creates an authentication failure.
  const StoreAuthException(super.message, {super.store});

  @override
  String get label => 'StoreAuthException';
}

/// The store answered, but with an error status.
///
/// ## Parameters
///
/// ### Required
/// - **[message]**: Summary of the failure.
/// - **[statusCode]**: HTTP status the store returned.
///
/// ### Optional
/// - **[store]**: Which store produced the failure.
/// - **[code]**: The store's own error code, e.g. `FORBIDDEN_ERROR`.
/// - **[detail]**: The store's longer explanation, when it sends one.
class StoreApiException extends StoreConsoleException {
  /// Creates a failure carrying the store's HTTP status.
  const StoreApiException(
    super.message, {
    required this.statusCode,
    super.store,
    this.code,
    this.detail,
  });

  /// HTTP status the store returned.
  final int statusCode;

  /// The store's own error code, when it sends one.
  ///
  /// App Store Connect uses strings such as `FORBIDDEN_ERROR`; Google Play
  /// uses `reason` strings such as `quotaExceeded`.
  final String? code;

  /// The store's longer explanation, when it sends one.
  final String? detail;

  @override
  String get label => 'StoreApiException';

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write(store == null ? '' : '[${store!.displayName}] ')
      ..write('$label: HTTP $statusCode')
      ..write(code == null ? '' : ' ($code)')
      ..write(' — $message');
    if (detail != null) buffer.write('\n$detail');
    return buffer.toString();
  }
}

/// The store's quota for this endpoint is exhausted.
///
/// Google Play allows 200 review reads per hour and 2,000 replies per day per
/// app; App Store Connect throttles per key. Both surface as `429`, except
/// Google Play which also uses `403` with a `quotaExceeded` reason.
class StoreRateLimitException extends StoreApiException {
  /// Creates a quota failure.
  const StoreRateLimitException(
    super.message, {
    required super.statusCode,
    super.store,
    super.code,
    super.detail,
    this.retryAfter,
  });

  /// How long to wait before retrying, when the store says so.
  final Duration? retryAfter;

  @override
  String get label => 'StoreRateLimitException';
}

/// The requested review does not exist, or is no longer reachable.
///
/// On Google Play this is the common case for a review older than a week: the
/// API only exposes the last seven days, so an ID captured earlier stops
/// resolving.
class ReviewNotFoundException extends StoreConsoleException {
  /// Creates a missing-review failure.
  const ReviewNotFoundException(super.message, {super.store, this.reviewId});

  /// The ID that could not be resolved.
  final String? reviewId;

  @override
  String get label => 'ReviewNotFoundException';
}
