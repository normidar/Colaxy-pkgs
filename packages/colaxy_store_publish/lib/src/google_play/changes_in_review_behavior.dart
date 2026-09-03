/// What committing should do when the app already has changes under review.
///
/// This is easy to miss and expensive to get wrong. Google Play's default,
/// applied when the parameter is left off entirely, is
/// [cancelInReviewAndSubmit] — so a routine metadata push can silently cancel
/// a review that was already in flight and restart the clock on it.
///
/// [errorIfInReview] is the safe choice for an unattended job: it fails
/// loudly, leaves the edit valid, and lets a human decide.
///
/// ## Example
///
/// ```dart
/// await session.commit(
///   changesInReviewBehavior: ChangesInReviewBehavior.errorIfInReview,
/// );
/// ```
enum ChangesInReviewBehavior {
  /// Cancel the review in progress, then submit everything together.
  ///
  /// Google Play's own default. Named explicitly here so that choosing it is
  /// a decision rather than an omission.
  cancelInReviewAndSubmit('CANCEL_IN_REVIEW_AND_SUBMIT'),

  /// Fail the commit instead of touching the review in progress.
  ///
  /// The edit stays valid after this failure, so it can be committed later
  /// once the review has cleared.
  errorIfInReview('ERROR_IF_IN_REVIEW');

  /// Creates a behaviour with the wire name Google Play uses for it.
  const ChangesInReviewBehavior(this.wireName);

  /// The value `androidpublisher` expects in `changesInReviewBehavior`.
  final String wireName;
}
