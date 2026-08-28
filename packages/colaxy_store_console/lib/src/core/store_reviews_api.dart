import 'package:colaxy_store_console/src/core/review_page.dart';
import 'package:colaxy_store_console/src/core/review_query.dart';
import 'package:colaxy_store_console/src/core/review_reply.dart';
import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_review.dart';

/// Reading and answering reviews for one app on one store.
///
/// Both `PlayReviewsApi` and `AppStoreReviewsApi` implement this, and
/// `StoreConsole.reviews` fans out across every configured store behind the
/// same interface — so code written against it does not care which store it
/// is talking to.
///
/// ## Example
///
/// ```dart
/// Future<void> answerOneStars(StoreReviewsApi api) async {
///   const query = ReviewQuery(ratings: {1}, hasReply: false);
///   await for (final review in api.list(query)) {
///     await api.reply(review.id, 'Sorry about that — write to us at …');
///   }
/// }
/// ```
abstract interface class StoreReviewsApi {
  /// Which store this instance talks to.
  Store get store;

  /// Every review matching [query], paging as it goes.
  ///
  /// The stream fetches the next page only when the previous one is consumed,
  /// so breaking out early stops the requests too — which matters on Google
  /// Play, where reads are capped at 200 per hour per app.
  Stream<StoreReview> list([ReviewQuery query]);

  /// A single page of reviews matching [query].
  ///
  /// Use this instead of [list] when you persist a cursor between runs.
  Future<ReviewPage> listPage([ReviewQuery query]);

  /// The review with [reviewId], or `null` if the store has no such review.
  ///
  /// Google Play only keeps the last seven days reachable, so an older ID
  /// resolves to `null` there even though the review still exists publicly.
  Future<StoreReview?> get(String reviewId);

  /// Replies to [reviewId] with [body], returning the stored reply.
  ///
  /// Replying again to a review that already has a reply replaces it on both
  /// stores; neither keeps a history.
  ///
  /// Throws [ArgumentError] if [body] is empty, or — on Google Play, whose
  /// 350-character limit Google documents — if it is too long, so an
  /// over-long reply fails locally instead of burning one of the 2,000 daily
  /// writes. Apple publishes no limit, so none is enforced there.
  Future<ReviewReply> reply(String reviewId, String body);

  /// Releases the underlying HTTP client.
  ///
  /// Call this when you are done, or the process will not exit.
  void close();
}
