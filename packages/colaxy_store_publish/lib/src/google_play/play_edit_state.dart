/// Where an edit is in its lifecycle.
///
/// ## Example
///
/// ```dart
/// if (session.state == PlayEditState.open) await session.commit();
/// ```
enum PlayEditState {
  /// Changes can be staged, and nothing has reached the store.
  open,

  /// Committed. Every staged change is live, or queued for review.
  committed,

  /// Discarded. Every staged change is gone and nothing reached the store.
  discarded,
}
