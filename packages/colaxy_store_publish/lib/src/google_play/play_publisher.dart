import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/google_play/changes_in_review_behavior.dart';
import 'package:colaxy_store_publish/src/google_play/play_api_guard.dart';
import 'package:colaxy_store_publish/src/google_play/play_edit_session.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:http/http.dart' as http;

/// The entry point for publishing to Google Play.
///
/// Holds the authenticated client and opens edits against one app.
///
/// **On credentials.** The `androidpublisher` OAuth scope has no read-only
/// variant: reading and writing are inseparable. A service account already
/// used with `colaxy_store_console` to read reviews therefore *already* had
/// the ability to publish a release — adding this package grants it nothing
/// new. What limits it is the per-app permission grant in Play Console, so
/// that is where a token meant only for reading has to be restricted.
///
/// ## Parameters
///
/// ### Required
/// - **`api`**: An authenticated Android Publisher client.
/// - **[packageName]**: The app's application ID, e.g. `com.example.app`.
///
/// ### Optional
/// - **`httpClient`**: The client backing `api`, closed by [close] unless
///   [ownsClient] says otherwise (default: `null`).
/// - **[ownsClient]**: Whether [close] closes `httpClient`
///   (default: `true`).
/// - **`guard`**: Retry and error translation (default: `PlayApiGuard()`).
///
/// ## Example
///
/// ```dart
/// final publisher = await PlayPublisher.authenticate(
///   account: PlayServiceAccount.fromFile('secrets/play-api.json'),
///   packageName: 'com.example.app',
/// );
/// try {
///   await publisher.edit((session) async {
///     await session.listings.update(listing);
///   });
/// } finally {
///   publisher.close();
/// }
/// ```
class PlayPublisher {
  /// Creates a publisher over an authenticated client.
  PlayPublisher({
    required play.AndroidPublisherApi api,
    required this.packageName,
    http.Client? httpClient,
    this.ownsClient = true,
    PlayApiGuard? guard,
  }) : _api = api,
       _httpClient = httpClient,
       _guard = guard ?? PlayApiGuard();

  /// Authenticates [account] and creates a publisher for [packageName].
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[account]**: A service account invited in Play Console with
  ///   permission to edit the app and release to the tracks you intend to
  ///   use.
  /// - **[packageName]**: The app's application ID.
  ///
  /// ### Optional
  /// - **[guard]**: Retry and error translation (default: `PlayApiGuard()`).
  ///
  /// ## Example
  ///
  /// ```dart
  /// final publisher = await PlayPublisher.authenticate(
  ///   account: PlayServiceAccount.fromFile('secrets/play-api.json'),
  ///   packageName: 'com.example.app',
  /// );
  /// ```
  static Future<PlayPublisher> authenticate({
    required PlayServiceAccount account,
    required String packageName,
    PlayApiGuard? guard,
  }) async {
    final client = await account.authenticate(
      scopes: const [PlayServiceAccount.androidPublisherScope],
    );
    return PlayPublisher(
      api: play.AndroidPublisherApi(client),
      packageName: packageName,
      httpClient: client,
      guard: guard,
    );
  }

  /// The app's application ID.
  final String packageName;

  /// Whether [close] should close the client this object was given.
  ///
  /// Pass `false` when the same authenticated client also backs a
  /// `colaxy_store_console` client — one token covers both, and letting the
  /// first `close()` shut it would break the second.
  final bool ownsClient;

  final play.AndroidPublisherApi _api;
  final http.Client? _httpClient;
  final PlayApiGuard _guard;

  /// Opens an edit, leaving its lifetime to the caller.
  ///
  /// The edit holds a lock on the app's next commit from this moment, so it
  /// has to be committed or discarded. Prefer [edit], which does that.
  Future<PlayEditSession> openEdit() =>
      PlayEditSession.open(api: _api, packageName: packageName, guard: _guard);

  /// Opens an edit, runs [body] against it, and commits.
  ///
  /// If [body] throws, the edit is discarded and the original error is
  /// rethrown — a half-staged edit left behind is what makes the *next* CI
  /// run fail, with an error that names nothing about this one.
  ///
  /// A failing **commit** is discarded too, which costs something worth
  /// knowing: a commit refused by
  /// [ChangesInReviewBehavior.errorIfInReview] leaves the edit valid and
  /// committable once the review clears, and discarding throws that away.
  /// Callers who want to hold an edit across that wait should drive
  /// [openEdit] themselves.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[body]**: Stages changes against the session it is given.
  ///
  /// ### Optional
  /// - **[dryRun]**: Ask Google Play to validate the staged changes, then
  ///   discard them (default: `false`). This is a real dry run — the same
  ///   check the commit would run, performed by Google rather than imitated
  ///   locally.
  /// - **[changesInReviewBehavior]**: What to do if the app already has
  ///   changes under review (default: `null`, leaving Google's default of
  ///   cancelling that review).
  /// - **[changesNotSentForReview]**: Stage the changes without submitting
  ///   them for review (default: `false`).
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Check a metadata push without touching the store.
  /// final report = await publisher.edit(
  ///   metadataPublisher.publish,
  ///   dryRun: true,
  /// );
  /// ```
  Future<T> edit<T>(
    Future<T> Function(PlayEditSession session) body, {
    bool dryRun = false,
    ChangesInReviewBehavior? changesInReviewBehavior,
    bool changesNotSentForReview = false,
  }) async {
    final session = await openEdit();
    T result;
    try {
      result = await body(session);
    } on Object {
      await session.discardQuietly();
      rethrow;
    }

    if (dryRun) {
      try {
        await session.validate();
      } finally {
        await session.discardQuietly();
      }
      return result;
    }

    try {
      await session.commit(
        changesInReviewBehavior: changesInReviewBehavior,
        changesNotSentForReview: changesNotSentForReview,
      );
    } on Object {
      await session.discardQuietly();
      rethrow;
    }
    return result;
  }

  /// Closes the authenticated client, when this object owns it.
  void close() {
    if (ownsClient) _httpClient?.close();
  }
}
