import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/core/store_publish_exception.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:meta/meta.dart';

/// Runs `androidpublisher` calls with retries, and translates their failures.
///
/// Every request in this package goes through one of these, for two reasons.
///
/// **Errors.** `googleapis` reports failures as `DetailedApiRequestError`.
/// Letting that escape would force every caller to depend on `googleapis`
/// just to tell a quota error from a permission error, so it is translated
/// into the `colaxy_store_console` exception hierarchy — the same one the
/// read-side client raises, so a pipeline that reads and writes has one set
/// of exceptions to handle.
///
/// **Retries.** Uploads fail transiently more often than reads do: a
/// screenshot push is many requests, each one large, and a `503` partway
/// through would otherwise abandon a half-built edit.
///
/// ## Parameters
///
/// ### Optional
/// - **[retryPolicy]**: When to try again (default: `RetryPolicy()`, three
///   attempts).
/// - **[onLog]**: Receives one line per retry and wait (default: `null`,
///   logging nothing).
///
/// ## Example
///
/// ```dart
/// final guard = PlayApiGuard(
///   retryPolicy: const RetryPolicy(maxAttempts: 5),
///   onLog: (message) => stderr.writeln('[play] $message'),
/// );
/// ```
class PlayApiGuard {
  /// Creates a guard.
  PlayApiGuard({
    this.retryPolicy = const RetryPolicy(),
    this.onLog,
    @visibleForTesting Future<void> Function(Duration)? sleep,
  }) : _sleep = sleep ?? _wait;

  /// When to try a rejected request again.
  final RetryPolicy retryPolicy;

  /// Receives one line per retry and wait.
  final StoreConsoleLog? onLog;

  final Future<void> Function(Duration) _sleep;

  static Future<void> _wait(Duration duration) =>
      Future<void>.delayed(duration);

  /// Runs [request], retrying per [retryPolicy] and translating failures.
  ///
  /// [description] names the operation in log lines, e.g.
  /// `'listings.update (ja-JP)'`. It never reaches Google.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final edit = await guard.run(
  ///   'edits.insert',
  ///   () => api.edits.insert(play.AppEdit(), packageName),
  /// );
  /// ```
  Future<T> run<T>(String description, Future<T> Function() request) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await request();
      } on play.DetailedApiRequestError catch (error) {
        final translated = translate(error);
        final status = error.status ?? 0;

        // A quota failure arrives as 403 from this API, which the policy
        // would not retry on status alone — so the decision follows the
        // translated type. A conflicting edit is never retried: replaying the
        // same commit against the same stale snapshot fails identically.
        final retryable =
            translated is! PlayEditConflictException &&
            (translated is StoreRateLimitException ||
                retryPolicy.shouldRetry(attempt: attempt, statusCode: status));
        // `shouldRetry` bounds the attempt count, but the rate-limit branch
        // bypasses it — without this the quota path would loop forever.
        if (!retryable || attempt >= retryPolicy.maxAttempts) throw translated;

        final wait = retryPolicy.backoffFor(attempt);
        onLog?.call(
          '$status from Google Play on $description; retrying in '
          '${wait.inMilliseconds}ms (attempt $attempt of '
          '${retryPolicy.maxAttempts})',
        );
        await _sleep(wait);
      }
    }
  }

  /// Maps a `googleapis` failure onto this package's exceptions.
  ///
  /// Exposed for tests and for callers that drive `androidpublisher`
  /// themselves but want the same interpretation of its errors.
  @visibleForTesting
  StoreConsoleException translate(play.DetailedApiRequestError error) {
    final status = error.status ?? 0;
    final message = error.message ?? 'Google Play rejected the request';
    final reason = error.errors.isEmpty ? null : error.errors.first.reason;

    // Play reports an exhausted quota as 403 with a `quotaExceeded` reason,
    // not the 429 the rest of Google uses. Matching on 'uota' covers both
    // `quotaExceeded` and `dailyLimitExceeded`-style variants without
    // guessing at the full list.
    final quotaExceeded =
        status == 429 ||
        (status == 403 &&
            error.errors.any(
              (detail) => detail.reason?.contains('uota') ?? false,
            ));
    if (quotaExceeded) {
      return StoreRateLimitException(
        message,
        statusCode: status,
        store: Store.googlePlay,
        code: reason,
      );
    }

    if (status == 409) {
      return PlayEditConflictException(
        message,
        statusCode: status,
        code: reason,
        detail:
            'The app changed since this edit was created. Open a new edit '
            'and apply the changes again. In CI this usually means two jobs '
            'published at once.',
      );
    }

    if (status == 401 || status == 403) {
      return StoreAuthException(
        '$message. Check that the service account is invited in Play Console '
        'under Users and permissions. Publishing needs more than the '
        'read permissions: "Edit and delete draft apps" and "Release apps to '
        'testing tracks" or "Release to production" as appropriate.',
        store: Store.googlePlay,
      );
    }

    if (status == 404) {
      return PlayEditExpiredException(
        '$message. Either the edit expired or was already committed, or the '
        'package name does not name an app this service account can see.',
        statusCode: status,
        code: reason,
      );
    }

    return StoreApiException(
      message,
      statusCode: status,
      store: Store.googlePlay,
      code: reason,
    );
  }
}
