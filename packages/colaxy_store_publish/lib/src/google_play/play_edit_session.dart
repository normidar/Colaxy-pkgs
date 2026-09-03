import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/google_play/changes_in_review_behavior.dart';
import 'package:colaxy_store_publish/src/google_play/play_api_guard.dart';
import 'package:colaxy_store_publish/src/google_play/play_bundles_api.dart';
import 'package:colaxy_store_publish/src/google_play/play_edit_state.dart';
import 'package:colaxy_store_publish/src/google_play/play_images_api.dart';
import 'package:colaxy_store_publish/src/google_play/play_listings_api.dart';
import 'package:colaxy_store_publish/src/google_play/play_tracks_api.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;

/// One Google Play edit: a transaction over an app's store presence.
///
/// Everything staged through [listings], [images], [tracks] and [bundles] is
/// invisible on the store until [commit]. Until then the edit can be thrown
/// away with [discard] and nothing partial remains — which is the property
/// that makes an interrupted publish safe on this store, and the reason this
/// class does not hide [commit] behind a friendlier method that "publishes".
/// A caller who cannot see the commit cannot know when the transaction ended.
///
/// [validate] asks Google to check the staged changes without applying them,
/// which is a real dry run rather than a local imitation of one.
///
/// **Edits expire.** [expiresAt] carries the deadline Google set when the
/// edit was created; a long screenshot upload can outlive it. **Edits are
/// also exclusive**: committing fails with `PlayEditConflictException` if
/// anything else was committed against the app in the meantime, which is how
/// two CI jobs racing each other shows up.
///
/// ## Example
///
/// ```dart
/// final session = await PlayEditSession.open(
///   api: api,
///   packageName: 'com.example.app',
/// );
/// try {
///   await session.listings.update(listing);
///   await session.commit();
/// } catch (_) {
///   await session.discardQuietly();
///   rethrow;
/// }
/// ```
class PlayEditSession {
  PlayEditSession._({
    required play.AndroidPublisherApi api,
    required this.packageName,
    required this.editId,
    required this.expiresAt,
    required PlayApiGuard guard,
  }) : _api = api,
       _guard = guard,
       listings = PlayListingsApi(
         api: api,
         packageName: packageName,
         editId: editId,
         guard: guard,
       ),
       images = PlayImagesApi(
         api: api,
         packageName: packageName,
         editId: editId,
         guard: guard,
       ),
       tracks = PlayTracksApi(
         api: api,
         packageName: packageName,
         editId: editId,
         guard: guard,
       ),
       bundles = PlayBundlesApi(
         api: api,
         packageName: packageName,
         editId: editId,
         guard: guard,
       );

  /// Opens a new edit against [packageName].
  ///
  /// The edit exists on Google Play from this moment and holds a lock on the
  /// app's next commit, so an abandoned session is not free: discard it, or
  /// let it expire.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[api]**: An authenticated Android Publisher client.
  /// - **[packageName]**: The app's application ID.
  ///
  /// ### Optional
  /// - **[guard]**: Retry and error translation (default: `PlayApiGuard()`).
  static Future<PlayEditSession> open({
    required play.AndroidPublisherApi api,
    required String packageName,
    PlayApiGuard? guard,
  }) async {
    final effectiveGuard = guard ?? PlayApiGuard();
    final edit = await effectiveGuard.run(
      'edits.insert',
      () => api.edits.insert(play.AppEdit(), packageName),
    );
    final id = edit.id;
    if (id == null) {
      throw const StoreApiException(
        'Google Play created an edit but did not return its id.',
        statusCode: 200,
        store: Store.googlePlay,
      );
    }
    return PlayEditSession._(
      api: api,
      packageName: packageName,
      editId: id,
      expiresAt: _expiry(edit.expiryTimeSeconds),
      guard: effectiveGuard,
    );
  }

  /// The app's application ID.
  final String packageName;

  /// Google's identifier for this edit.
  final String editId;

  /// When Google Play will drop this edit, if it said.
  ///
  /// Worth checking before a long upload: an edit that expires mid-run makes
  /// every subsequent call fail with `PlayEditExpiredException`, and the
  /// staged changes are gone.
  final DateTime? expiresAt;

  /// The store listing text staged in this edit.
  final PlayListingsApi listings;

  /// The screenshots and graphics staged in this edit.
  final PlayImagesApi images;

  /// The release tracks staged in this edit.
  final PlayTracksApi tracks;

  /// The app bundles attached to this edit.
  final PlayBundlesApi bundles;

  final play.AndroidPublisherApi _api;
  final PlayApiGuard _guard;

  PlayEditState _state = PlayEditState.open;

  /// Where this edit is in its lifecycle.
  PlayEditState get state => _state;

  /// Whether changes can still be staged.
  bool get isOpen => _state == PlayEditState.open;

  /// How long until [expiresAt], or `null` if Google gave no deadline.
  ///
  /// Negative once the deadline has passed.
  Duration? get timeRemaining =>
      expiresAt?.difference(DateTime.now().toUtc());

  /// Asks Google Play to check the staged changes without applying them.
  ///
  /// This is what a dry run should be: the same validation the commit would
  /// run, performed by the party that decides. The edit stays open and
  /// committable afterwards.
  Future<void> validate() async {
    _requireOpen('validate');
    await _guard.run(
      'edits.validate',
      () => _api.edits.validate(packageName, editId),
    );
  }

  /// Applies every staged change to the store.
  ///
  /// After this the edit is spent: [state] becomes
  /// [PlayEditState.committed] and nothing further can be staged.
  ///
  /// ## Parameters
  ///
  /// ### Optional
  /// - **[changesInReviewBehavior]**: What to do if the app already has
  ///   changes under review (default: `null`, which leaves Google's own
  ///   default of cancelling that review and resubmitting — see
  ///   [ChangesInReviewBehavior]).
  /// - **[changesNotSentForReview]**: Stage the changes without submitting
  ///   them for review, leaving that to a human in Play Console (default:
  ///   `false`).
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Refuse to disturb a review that is already running.
  /// await session.commit(
  ///   changesInReviewBehavior: ChangesInReviewBehavior.errorIfInReview,
  /// );
  /// ```
  Future<void> commit({
    ChangesInReviewBehavior? changesInReviewBehavior,
    bool changesNotSentForReview = false,
  }) async {
    _requireOpen('commit');
    await _guard.run(
      'edits.commit',
      () => _api.edits.commit(
        packageName,
        editId,
        changesInReviewBehavior: changesInReviewBehavior?.wireName,
        changesNotSentForReview: changesNotSentForReview ? true : null,
      ),
    );
    _state = PlayEditState.committed;
  }

  /// Throws the edit away. Nothing staged in it reaches the store.
  ///
  /// Worth calling rather than leaving the edit to expire: an app can hold
  /// only so many open edits, and an abandoned one from a crashed CI job is
  /// what makes the next job fail for no visible reason.
  Future<void> discard() async {
    _requireOpen('discard');
    await _guard.run(
      'edits.delete',
      () => _api.edits.delete(packageName, editId),
    );
    _state = PlayEditState.discarded;
  }

  /// Discards the edit, swallowing any failure.
  ///
  /// For the `catch` block of a publish that has already gone wrong. A
  /// failure to clean up is not the failure worth reporting there, and
  /// letting it propagate would replace the real error with a confusing one.
  ///
  /// Answers whether the discard succeeded, for callers that want to log it.
  Future<bool> discardQuietly() async {
    if (!isOpen) return false;
    try {
      await discard();
      return true;
    } on StoreConsoleException {
      _state = PlayEditState.discarded;
      return false;
    }
  }

  void _requireOpen(String action) {
    if (isOpen) return;
    throw StateError(
      'Cannot $action edit $editId: it was already ${_state.name}. Open a '
      'new edit for further changes.',
    );
  }

  /// Parses the `expiryTimeSeconds` Google returns, which is seconds as text.
  static DateTime? _expiry(String? seconds) {
    if (seconds == null) return null;
    final parsed = int.tryParse(seconds);
    if (parsed == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(parsed * 1000, isUtc: true);
  }
}
