import 'dart:math' as math;

/// When and how long to wait before retrying a rejected request.
///
/// Both stores fail transiently in ways that are not the caller's fault:
/// Apple returns `500 UNEXPECTED_ERROR` on endpoints that work seconds later,
/// and both throttle with `429`. Retrying those with a growing wait turns a
/// crashed job into a slow one.
///
/// Statuses that mean "your request is wrong" — `400`, `403`, `404` — are
/// never retried, because the same request will fail the same way. `401` is
/// also excluded here: it is handled separately by re-signing the token once,
/// which is a fix rather than a wait.
///
/// ## Parameters
///
/// ### Optional
/// - **`maxAttempts`**: Total tries, including the first (default: `3`).
/// - **`initialBackoff`**: Wait before the second attempt (default: 1 second).
/// - **`maxBackoff`**: Ceiling on the wait (default: 30 seconds).
/// - **`multiplier`**: Growth factor per attempt (default: `2.0`).
///
/// ## Example
///
/// ```dart
/// // Patient, for a long-running report poll.
/// const policy = RetryPolicy(
///   maxAttempts: 8,
///   maxBackoff: Duration(minutes: 2),
/// );
/// ```
class RetryPolicy {
  /// Creates a retry policy.
  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 30),
    this.multiplier = 2.0,
  }) : assert(maxAttempts >= 1, 'maxAttempts must be at least 1'),
       assert(multiplier >= 1, 'multiplier must be at least 1');

  /// A policy that never retries.
  ///
  /// Use it in tests, and wherever a caller would rather see the failure than
  /// wait — a retry loop inside a request that is itself being retried
  /// multiplies the total wait.
  const RetryPolicy.none()
    : maxAttempts = 1,
      initialBackoff = Duration.zero,
      maxBackoff = Duration.zero,
      multiplier = 1;

  /// Statuses worth trying again.
  ///
  /// `429` is throttling; the `5xx` entries are the ones both stores are
  /// observed to return spuriously. Other `5xx` codes are left alone, since
  /// an unrecognised server error is more likely to be permanent.
  static const retryableStatuses = {429, 500, 502, 503, 504};

  /// Total tries, including the first.
  final int maxAttempts;

  /// Wait before the second attempt.
  final Duration initialBackoff;

  /// Ceiling on the wait.
  final Duration maxBackoff;

  /// Growth factor per attempt.
  final double multiplier;

  /// Whether a request that returned [statusCode] should be tried again.
  ///
  /// [attempt] is 1-based and counts the try that just failed.
  bool shouldRetry({required int attempt, required int statusCode}) =>
      attempt < maxAttempts && retryableStatuses.contains(statusCode);

  /// How long to wait after [attempt] failed tries.
  ///
  /// [retryAfter] wins when the store sent one — it knows its own quota
  /// window better than any backoff curve — but is still capped by
  /// [maxBackoff] so a misreported header cannot stall a job for hours.
  Duration backoffFor(int attempt, {Duration? retryAfter}) {
    if (retryAfter != null) {
      return retryAfter > maxBackoff ? maxBackoff : retryAfter;
    }
    final grown =
        initialBackoff.inMilliseconds * math.pow(multiplier, attempt - 1);
    final capped = math.min(grown, maxBackoff.inMilliseconds.toDouble());
    return Duration(milliseconds: capped.round());
  }
}
