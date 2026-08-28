import 'package:colaxy_store_console/src/app_store/app_store_connect_client.dart';
import 'package:colaxy_store_console/src/app_store/app_store_review_mapper.dart';
import 'package:colaxy_store_console/src/core/review_page.dart';
import 'package:colaxy_store_console/src/core/review_query.dart';
import 'package:colaxy_store_console/src/core/review_reply.dart';
import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_console_exception.dart';
import 'package:colaxy_store_console/src/core/store_review.dart';
import 'package:colaxy_store_console/src/core/store_reviews_api.dart';

/// Reads and answers App Store reviews for one app.
///
/// Unlike Google Play, Apple keeps the full review history reachable and
/// filters server-side, so every field of a [ReviewQuery] except
/// `translationLanguage` is honoured here.
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: Transport to issue requests through.
/// - **[appId]**: The app's App Store Connect resource ID — the numeric ID
///   in the App Store Connect URL, not the bundle ID.
///
/// ## Example
///
/// ```dart
/// final api = AppStoreReviewsApi(client: client, appId: '6740000000');
/// final page = await api.listPage(const ReviewQuery(ratings: {1, 2}));
/// ```
class AppStoreReviewsApi implements StoreReviewsApi {
  /// Creates a reviews client for one App Store app.
  AppStoreReviewsApi({
    required AppStoreConnectClient client,
    required this.appId,
  }) : _client = client;

  /// Longest response Apple accepts, in characters.
  static const maxReplyLength = 5970;

  /// Largest page Apple will return.
  static const maxPageSize = 200;

  /// The app's App Store Connect resource ID.
  final String appId;

  final AppStoreConnectClient _client;

  @override
  Store get store => Store.appStore;

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
    // A cursor is Apple's own `links.next`, already carrying every filter, so
    // it is followed verbatim rather than rebuilt from `query`.
    final cursor = query.cursor;
    final json = cursor != null
        ? await _client.getUri(Uri.parse(cursor))
        : await _client.getJson(
            '/v1/apps/$appId/customerReviews',
            query: _queryParameters(query),
          );

    final data = json['data'];
    final responses = AppStoreReviewMapper.includedResponses(json['included']);
    final reviews = <StoreReview>[];
    if (data is List) {
      for (final entry in data) {
        if (entry is! Map<String, dynamic>) continue;
        reviews.add(
          AppStoreReviewMapper.review(entry, responsesById: responses),
        );
      }
    }

    return ReviewPage(
      store: Store.appStore,
      reviews: reviews,
      nextCursor: _nextLink(json),
      total: _total(json),
    );
  }

  @override
  Future<StoreReview?> get(String reviewId) async {
    try {
      final json = await _client.getJson(
        '/v1/customerReviews/$reviewId',
        query: const {'include': 'response'},
      );
      final data = json['data'];
      if (data is! Map<String, dynamic>) return null;
      return AppStoreReviewMapper.review(
        data,
        responsesById: AppStoreReviewMapper.includedResponses(json['included']),
      );
    } on StoreApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<ReviewReply> reply(String reviewId, String body) async {
    _validateBody(body);

    // Apple models a reply as its own resource, so replacing an existing one
    // is a PATCH against that resource — POSTing a second time returns a
    // 409. Look first, then choose the verb.
    final existing = await _existingResponseId(reviewId);
    final json = existing == null
        ? await _client.postJson('/v1/customerReviewResponses', {
            'data': {
              'type': 'customerReviewResponses',
              'attributes': {'responseBody': body},
              'relationships': {
                'review': {
                  'data': {'type': 'customerReviews', 'id': reviewId},
                },
              },
            },
          })
        : await _client.patchJson('/v1/customerReviewResponses/$existing', {
            'data': {
              'type': 'customerReviewResponses',
              'id': existing,
              'attributes': {'responseBody': body},
            },
          });

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const StoreApiException(
        'App Store Connect accepted the reply but returned no resource.',
        statusCode: 200,
        store: Store.appStore,
      );
    }
    return AppStoreReviewMapper.reply(data);
  }

  /// Deletes the developer response to [reviewId], if there is one.
  ///
  /// Returns whether a response was actually removed. Google Play has no
  /// equivalent, which is why this is not on [StoreReviewsApi].
  Future<bool> deleteReply(String reviewId) async {
    final existing = await _existingResponseId(reviewId);
    if (existing == null) return false;
    await _client.delete('/v1/customerReviewResponses/$existing');
    return true;
  }

  @override
  void close() => _client.close();

  /// The ID of [reviewId]'s existing response, or `null` if it has none.
  Future<String?> _existingResponseId(String reviewId) async {
    try {
      final json = await _client.getJson(
        '/v1/customerReviews/$reviewId/response',
      );
      final data = json['data'];
      return data is Map<String, dynamic> ? data['id'] as String? : null;
    } on StoreApiException catch (error) {
      // Apple answers 404 both for "no response yet" and for "no such
      // review". Treating it as "no response" is right for the first and
      // harmless for the second, where the follow-up POST fails anyway with
      // a message that names the missing review.
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  void _validateBody(String body) {
    if (body.trim().isEmpty) {
      throw ArgumentError.value(body, 'body', 'Reply body cannot be empty');
    }
    if (body.length > maxReplyLength) {
      throw ArgumentError.value(
        body.length,
        'body.length',
        'App Store replies are limited to $maxReplyLength characters',
      );
    }
  }

  Map<String, Object?> _queryParameters(ReviewQuery query) => {
    'include': 'response',
    'limit': query.pageSize?.clamp(1, maxPageSize),
    'sort': _sort(query.sort),
    'filter[rating]': query.ratings.toList()..sort(),
    'filter[territory]': query.territories.toList()..sort(),
    'exists[publishedResponse]': query.hasReply,
  };

  static String? _sort(ReviewSort? sort) => switch (sort) {
    null => null,
    ReviewSort.newestFirst => '-createdDate',
    ReviewSort.oldestFirst => 'createdDate',
    ReviewSort.highestRating => '-rating',
    ReviewSort.lowestRating => 'rating',
  };

  static String? _nextLink(Map<String, dynamic> json) {
    final links = json['links'];
    if (links is! Map<String, dynamic>) return null;
    final next = links['next'];
    return next is String && next.isNotEmpty ? next : null;
  }

  static int? _total(Map<String, dynamic> json) {
    final meta = json['meta'];
    if (meta is! Map<String, dynamic>) return null;
    final paging = meta['paging'];
    if (paging is! Map<String, dynamic>) return null;
    final total = paging['total'];
    return total is int ? total : null;
  }
}
