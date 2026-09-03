import 'package:colaxy_store_console/colaxy_store_console.dart';

/// Another edit changed the app while this one was open.
///
/// Google Play serialises edits per app: an edit is created against a snapshot
/// of the app, and committing it fails if anything else was committed in the
/// meantime. In CI this is the shape a race between two jobs takes — both open
/// an edit, both succeed at every intermediate call, and the second `commit`
/// is the first sign that anything was wrong.
///
/// The edit is not usable after this. Open a new one and replay the changes.
///
/// ## Parameters
///
/// ### Required
/// - **[message]**: What Google Play said.
/// - **[statusCode]**: HTTP status, `409` in every observed case.
///
/// ### Optional
/// - **[code]**: Google's own reason string.
/// - **[detail]**: Google's longer explanation, when it sends one.
class PlayEditConflictException extends StoreApiException {
  /// Creates a conflicting-edit failure.
  const PlayEditConflictException(
    super.message, {
    required super.statusCode,
    super.code,
    super.detail,
  }) : super(store: Store.googlePlay);

  @override
  String get label => 'PlayEditConflictException';
}

/// The edit no longer exists on Google Play.
///
/// Edits expire. `PlayEditSession.expiresAt` carries the deadline Google
/// returned when the edit was created, but an edit can also disappear because
/// it was already committed, or discarded by another job.
///
/// This is distinct from a `404` on the app itself, which means the package
/// name is wrong or the service account was never invited to it.
///
/// ## Parameters
///
/// ### Required
/// - **[message]**: What Google Play said.
/// - **[statusCode]**: HTTP status, `404`.
///
/// ### Optional
/// - **[editId]**: The edit that could not be resolved.
class PlayEditExpiredException extends StoreApiException {
  /// Creates an expired-edit failure.
  const PlayEditExpiredException(
    super.message, {
    required super.statusCode,
    this.editId,
    super.code,
  }) : super(store: Store.googlePlay);

  /// The edit that could not be resolved.
  final String? editId;

  @override
  String get label => 'PlayEditExpiredException';
}

/// The local file layout is not something this package can publish.
///
/// Raised before any request is made: a metadata directory that does not
/// exist, a screenshot directory holding no images, a listing whose locale
/// cannot be derived from its path.
///
/// Store-side rules — image dimensions, description length, whether a locale
/// is enabled for the app — are deliberately *not* raised here. Google
/// enforces those, and enforcing them a second time locally only ever blocks
/// combinations that would in fact have been accepted.
///
/// ## Parameters
///
/// ### Required
/// - **[message]**: What is wrong with the layout.
///
/// ### Optional
/// - **[path]**: The file or directory the complaint is about.
class FastlaneLayoutException extends StoreConsoleException {
  /// Creates a layout failure.
  const FastlaneLayoutException(super.message, {this.path})
    : super(store: Store.googlePlay);

  /// The file or directory the complaint is about.
  final String? path;

  @override
  String get label => 'FastlaneLayoutException';

  @override
  String toString() {
    final suffix = path == null ? '' : ' ($path)';
    return '[${Store.googlePlay.displayName}] $label: $message$suffix';
  }
}
