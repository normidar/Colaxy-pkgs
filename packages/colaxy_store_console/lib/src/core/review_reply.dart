import 'package:colaxy_store_console/src/core/store.dart';

/// Whether a developer reply is live on the store yet.
enum ReviewReplyState {
  /// Visible to users on the store listing.
  published,

  /// Accepted by App Store Connect, not yet shown on the store.
  ///
  /// Google Play has no equivalent — replies there go live directly.
  pendingPublish,

  /// The store reported a state this package does not model.
  unknown,
}

/// A developer's reply to a `StoreReview`.
///
/// ## Parameters
///
/// ### Required
/// - **[store]**: Which store the reply lives on.
/// - **[body]**: The reply text.
///
/// ### Optional
/// - **[id]**: The reply's own resource ID (App Store Connect only; Google
///   Play replies are not addressable, default: `null`).
/// - **[lastModified]**: When the reply was last edited (default: `null`).
/// - **[state]**: Publication state (default: [ReviewReplyState.published]).
class ReviewReply {
  /// Creates a developer reply.
  const ReviewReply({
    required this.store,
    required this.body,
    this.id,
    this.lastModified,
    this.state = ReviewReplyState.published,
  });

  /// Which store the reply lives on.
  final Store store;

  /// The reply text as shown to users.
  final String body;

  /// The reply's own resource ID.
  ///
  /// App Store Connect models a reply as a `customerReviewResponses`
  /// resource with its own ID, which is what you need in order to update or
  /// delete it. Google Play folds the reply into the review, so this is
  /// `null` there.
  final String? id;

  /// When the reply was last edited.
  final DateTime? lastModified;

  /// Whether the reply is live on the store.
  final ReviewReplyState state;

  @override
  String toString() =>
      'ReviewReply(${store.displayName}, ${state.name}, "$body")';
}
