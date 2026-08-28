import 'package:colaxy_store_console/src/core/review_reply.dart';
import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_review.dart';

/// Turns App Store Connect JSON:API resources into this package's models.
///
/// Kept separate from the HTTP client so the mapping can be tested against
/// recorded payloads without a network or a signing key.
abstract final class AppStoreReviewMapper {
  /// Maps one `customerReviews` resource to a [StoreReview].
  ///
  /// [responsesById] holds any `customerReviewResponses` resources from the
  /// response's `included` array, keyed by ID. Apple only sends the reply as
  /// a *relationship* on the review, so without the included lookup every
  /// review would come back reading as unanswered.
  static StoreReview review(
    Map<String, dynamic> resource, {
    Map<String, Map<String, dynamic>> responsesById = const {},
  }) {
    final attributes = _map(resource['attributes']);
    final responseId = _responseId(resource);
    final responseResource = responseId == null
        ? null
        : responsesById[responseId];

    return StoreReview(
      store: Store.appStore,
      id: resource['id'] as String? ?? '',
      rating: _int(attributes['rating']) ?? 0,
      title: _nonEmpty(attributes['title']),
      body: _nonEmpty(attributes['body']),
      authorName: _nonEmpty(attributes['reviewerNickname']),
      createdAt: _dateTime(attributes['createdDate']),
      territory: _nonEmpty(attributes['territory']),
      reply: responseResource == null ? null : reply(responseResource),
      raw: resource,
    );
  }

  /// Maps one `customerReviewResponses` resource to a [ReviewReply].
  static ReviewReply reply(Map<String, dynamic> resource) {
    final attributes = _map(resource['attributes']);
    return ReviewReply(
      store: Store.appStore,
      id: resource['id'] as String?,
      body: attributes['responseBody'] as String? ?? '',
      lastModified: _dateTime(attributes['lastModifiedDate']),
      state: replyState(attributes['state'] as String?),
    );
  }

  /// Maps Apple's response `state` string onto [ReviewReplyState].
  ///
  /// An unrecognised value maps to [ReviewReplyState.unknown] rather than
  /// throwing: Apple adds enum members without notice, and a new state is no
  /// reason to fail a whole page of reviews.
  static ReviewReplyState replyState(String? state) => switch (state) {
    'PUBLISHED' => ReviewReplyState.published,
    'PENDING_PUBLISH' => ReviewReplyState.pendingPublish,
    _ => ReviewReplyState.unknown,
  };

  /// Indexes a JSON:API `included` array by resource ID.
  ///
  /// Only `customerReviewResponses` entries are kept; the same array also
  /// carries territories when they are requested.
  static Map<String, Map<String, dynamic>> includedResponses(
    Object? included,
  ) {
    if (included is! List) return const {};
    final byId = <String, Map<String, dynamic>>{};
    for (final entry in included) {
      if (entry is! Map<String, dynamic>) continue;
      if (entry['type'] != 'customerReviewResponses') continue;
      final id = entry['id'];
      if (id is String) byId[id] = entry;
    }
    return byId;
  }

  /// Pulls the reply ID out of a review's `relationships.response`.
  static String? _responseId(Map<String, dynamic> resource) {
    final relationships = _map(resource['relationships']);
    final response = _map(relationships['response']);
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;
    return data['id'] as String?;
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : const {};

  static int? _int(Object? value) => switch (value) {
    final int value => value,
    final String value => int.tryParse(value),
    _ => null,
  };

  static String? _nonEmpty(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }

  /// Parses an ISO 8601 timestamp, tolerating a value Apple sends malformed.
  static DateTime? _dateTime(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}
