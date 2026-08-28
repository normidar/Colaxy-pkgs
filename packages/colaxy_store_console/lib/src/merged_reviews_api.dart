import 'dart:async';

import 'package:colaxy_store_console/src/core/review_page.dart';
import 'package:colaxy_store_console/src/core/review_query.dart';
import 'package:colaxy_store_console/src/core/review_reply.dart';
import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_console_exception.dart';
import 'package:colaxy_store_console/src/core/store_review.dart';
import 'package:colaxy_store_console/src/core/store_reviews_api.dart';

/// Reviews from several stores behind one [StoreReviewsApi].
///
/// Each store keeps its own cursor, so there is no single opaque token that
/// spans both. That makes [listPage] meaningless across stores, and it throws
/// — use [list], or page each store's own API. Everything else fans out.
///
/// ## Parameters
///
/// ### Required
/// - **[delegates]**: The per-store clients to fan out to, at least one.
class MergedReviewsApi implements StoreReviewsApi {
  /// Creates a merged view over [delegates].
  MergedReviewsApi(this.delegates)
    : assert(
        delegates.isNotEmpty,
        'MergedReviewsApi needs at least one store',
      );

  /// The per-store clients this fans out to.
  final List<StoreReviewsApi> delegates;

  /// The store this reads from, when there is only one.
  ///
  /// Throws [StateError] when several stores are configured, since there is
  /// no single answer.
  @override
  Store get store {
    if (delegates.length == 1) return delegates.single.store;
    throw StateError(
      'MergedReviewsApi spans ${delegates.length} stores; read '
      'StoreReview.store on each result instead.',
    );
  }

  /// Every review from every store, one store fully drained before the next.
  ///
  /// The order is deliberate: interleaving would mean holding a page from
  /// each store in memory and would burn Google Play's 200-reads-per-hour
  /// quota even when the caller breaks out early. Sort the collected results
  /// by `StoreReview.timestamp` if you need a chronological view.
  ///
  /// `query.cursor` is dropped. Cursors are per-store — Apple's is a URL,
  /// Google's an opaque token — so forwarding one to every delegate would
  /// hand at least one store a cursor it cannot read. Each store starts from
  /// its own first page and pages itself from there.
  @override
  Stream<StoreReview> list([ReviewQuery query = const ReviewQuery()]) async* {
    final fromStart = query.cursor == null ? query : query.withCursor(null);
    for (final delegate in delegates) {
      yield* delegate.list(fromStart);
    }
  }

  /// Not supported across stores.
  ///
  /// Throws [UnsupportedError] unless exactly one store is configured, in
  /// which case it delegates.
  @override
  Future<ReviewPage> listPage([ReviewQuery query = const ReviewQuery()]) {
    if (delegates.length == 1) return delegates.single.listPage(query);
    throw UnsupportedError(
      'Cursors are per-store, so a merged page has no meaningful cursor. '
      'Use list(), or page each store through its own API.',
    );
  }

  /// The review with [reviewId], asking each store in turn.
  ///
  /// Review IDs are unique within a store, not across them. A collision is
  /// vanishingly unlikely given their formats, but the first match wins.
  @override
  Future<StoreReview?> get(String reviewId) async {
    for (final delegate in delegates) {
      final review = await delegate.get(reviewId);
      if (review != null) return review;
    }
    return null;
  }

  /// Replies to [reviewId] on whichever store owns it.
  ///
  /// This costs a lookup before the write, so prefer calling the owning
  /// store's API directly when you already know where the review came from —
  /// `review.store` tells you.
  ///
  /// Throws [ReviewNotFoundException] if no configured store has it.
  @override
  Future<ReviewReply> reply(String reviewId, String body) async {
    for (final delegate in delegates) {
      final review = await delegate.get(reviewId);
      if (review != null) return delegate.reply(reviewId, body);
    }
    throw ReviewNotFoundException(
      'No configured store has a review with ID "$reviewId".',
      reviewId: reviewId,
    );
  }

  @override
  void close() {
    for (final delegate in delegates) {
      delegate.close();
    }
  }
}
