import 'package:colaxy_store_console/src/core/retry_policy.dart';
import 'package:colaxy_store_console/src/core/review_page.dart';
import 'package:colaxy_store_console/src/core/review_query.dart';
import 'package:colaxy_store_console/src/core/review_reply.dart';
import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_console_exception.dart';
import 'package:colaxy_store_console/src/core/store_console_log.dart';
import 'package:colaxy_store_console/src/core/store_review.dart';
import 'package:colaxy_store_console/src/core/store_reviews_api.dart';
import 'package:colaxy_store_console/src/google_play/play_review_mapper.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// Reads and answers Google Play reviews for one app.
///
/// Three limits of the Google Play Developer API shape this class, and none
/// of them can be worked around client-side:
///
/// - **Only the last seven days are reachable.** Reviews created or edited
///   earlier are not returned and cannot be replied to. If you need history,
///   poll and store the results yourself.
/// - **Only reviews with text appear.** A bare star rating is invisible to
///   the API, so a rating average computed from these reviews will not match
///   the one in Play Console.
/// - **No server-side filter or sort.** [ReviewQuery.ratings] and
///   [ReviewQuery.hasReply] are applied to each page after it is fetched, and
///   [ReviewQuery.sort] and [ReviewQuery.territories] are ignored entirely.
///
/// Quota is 200 reads per hour and 2,000 replies per day, per app.
///
/// ## Parameters
///
/// ### Required
/// - **`api`**: An authenticated Android Publisher client.
/// - **[packageName]**: The app's application ID, e.g. `com.example.app`.
///
/// ### Optional
/// - **`httpClient`**: The client backing `api`, closed by [close] when
///   given (default: `null`, leaving lifetime to the caller).
/// - **[retryPolicy]**: When to retry a throttled or transiently failing
///   request (default: `RetryPolicy()`, three attempts).
/// - **[onLog]**: Receives one line per retry and wait (default: `null`,
///   logging nothing).
class PlayReviewsApi implements StoreReviewsApi {
  /// Creates a reviews client for one Google Play app.
  PlayReviewsApi({
    required play.AndroidPublisherApi api,
    required this.packageName,
    http.Client? httpClient,
    this.retryPolicy = const RetryPolicy(),
    this.onLog,
    @visibleForTesting Future<void> Function(Duration)? sleep,
  }) : _api = api,
       _httpClient = httpClient,
       _sleep = sleep ?? _wait;

  /// Longest reply Google Play accepts, in characters.
  static const maxReplyLength = 350;

  /// Largest page Google Play will return.
  static const maxPageSize = 100;

  /// The app's application ID.
  final String packageName;

  /// When to retry a throttled or transiently failing request.
  final RetryPolicy retryPolicy;

  /// Receives one line per retry and wait.
  final StoreConsoleLog? onLog;

  final play.AndroidPublisherApi _api;
  final http.Client? _httpClient;
  final Future<void> Function(Duration) _sleep;

  static Future<void> _wait(Duration duration) =>
      Future<void>.delayed(duration);

  @override
  Store get store => Store.googlePlay;

  @override
  Stream<StoreReview> list([ReviewQuery query = const ReviewQuery()]) async* {
    var current = query;
    while (true) {
      final page = await listPage(current);
      yield* Stream.fromIterable(page.reviews);
      if (page.isLast) return;
      current = current.withCursor(page.nextCursor);
    }
  }

  @override
  Future<ReviewPage> listPage([
    ReviewQuery query = const ReviewQuery(),
  ]) async {
    final response = await _guard(
      () => _api.reviews.list(
        packageName,
        maxResults: query.pageSize?.clamp(1, maxPageSize),
        token: query.cursor,
        translationLanguage: query.translationLanguage,
      ),
    );

    final mapped = <StoreReview>[];
    for (final source in response.reviews ?? const <play.Review>[]) {
      final review = PlayReviewMapper.review(source);
      // Play has no server-side filter, so it happens here. The page can end
      // up shorter than `pageSize`, or empty — hence `ReviewPage.isLast`
      // rather than a length check being the way to stop paging.
      if (!query.matches(
        rating: review.rating,
        reviewHasReply: review.hasReply,
      )) {
        continue;
      }
      mapped.add(review);
    }

    return ReviewPage(
      store: Store.googlePlay,
      reviews: mapped,
      nextCursor: response.tokenPagination?.nextPageToken,
    );
  }

  @override
  Future<StoreReview?> get(String reviewId) async {
    try {
      final source = await _guard(
        () => _api.reviews.get(packageName, reviewId),
      );
      return PlayReviewMapper.review(source);
    } on ReviewNotFoundException {
      return null;
    }
  }

  @override
  Future<ReviewReply> reply(String reviewId, String body) async {
    _validateBody(body);
    final response = await _guard(
      () => _api.reviews.reply(
        play.ReviewsReplyRequest(replyText: body),
        packageName,
        reviewId,
      ),
    );

    final result = response.result;
    if (result == null) {
      throw const StoreApiException(
        'Google Play accepted the reply but returned no result.',
        statusCode: 200,
        store: Store.googlePlay,
      );
    }
    return PlayReviewMapper.replyResult(result);
  }

  @override
  void close() => _httpClient?.close();

  void _validateBody(String body) {
    if (body.trim().isEmpty) {
      throw ArgumentError.value(body, 'body', 'Reply body cannot be empty');
    }
    if (body.length > maxReplyLength) {
      throw ArgumentError.value(
        body.length,
        'body.length',
        'Google Play replies are limited to $maxReplyLength characters',
      );
    }
  }

  /// Runs [request], translating `googleapis` errors into this package's and
  /// backing off per [retryPolicy].
  ///
  /// `DetailedApiRequestError` carries the status and message but is a
  /// `googleapis` type, so letting it escape would force callers to depend on
  /// `googleapis` just to catch a quota error.
  Future<T> _guard<T>(Future<T> Function() request) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await request();
      } on play.DetailedApiRequestError catch (error) {
        final translated = _translate(error);
        final status = error.status ?? 0;

        // A quota failure that Play reports as 403 is retryable even though a
        // plain 403 is not, so the decision follows the translated type
        // rather than the raw status.
        final retryable =
            translated is StoreRateLimitException ||
            retryPolicy.shouldRetry(attempt: attempt, statusCode: status);
        if (!retryable || attempt >= retryPolicy.maxAttempts) throw translated;

        final wait = retryPolicy.backoffFor(attempt);
        onLog?.call(
          '$status from Google Play; retrying in ${wait.inMilliseconds}ms '
          '(attempt $attempt of ${retryPolicy.maxAttempts})',
        );
        await _sleep(wait);
      }
    }
  }

  StoreConsoleException _translate(play.DetailedApiRequestError error) {
    final status = error.status ?? 0;
    final message = error.message ?? 'Google Play rejected the request';
    // Play signals an exhausted quota with 403 and a `quotaExceeded` reason,
    // not the 429 the rest of Google uses.
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
        code: error.errors.isEmpty ? null : error.errors.first.reason,
        detail:
            'Google Play allows 200 review reads per hour and 2,000 replies '
            'per day, per app.',
      );
    }
    if (status == 401) {
      return StoreAuthException(
        '$message. Check that the service account is invited in Play Console '
        'under Users and permissions, with "Reply to reviews" granted.',
        store: Store.googlePlay,
      );
    }
    if (status == 404) {
      return ReviewNotFoundException(
        '$message. Google Play only exposes reviews from the last seven days.',
        store: Store.googlePlay,
      );
    }
    return StoreApiException(
      message,
      statusCode: status,
      store: Store.googlePlay,
      code: error.errors.isEmpty ? null : error.errors.first.reason,
    );
  }
}
