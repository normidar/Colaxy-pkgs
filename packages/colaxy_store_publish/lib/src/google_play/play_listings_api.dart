import 'package:colaxy_store_publish/src/google_play/play_api_guard.dart';
import 'package:colaxy_store_publish/src/google_play/play_listing.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;

/// The store listing text inside one open edit.
///
/// Every change here is staged in the edit and invisible on the store until
/// the edit is committed. Nothing on this class publishes anything.
///
/// ## Parameters
///
/// ### Required
/// - **`api`**: An authenticated Android Publisher client.
/// - **[packageName]**: The app's application ID.
/// - **[editId]**: The open edit changes are staged in.
///
/// ### Optional
/// - **`guard`**: Retry and error translation (default: `PlayApiGuard()`).
///
/// ## Example
///
/// ```dart
/// await session.listings.update(
///   const PlayListing(language: 'ja-JP', title: '家計簿'),
/// );
/// ```
class PlayListingsApi {
  /// Creates a listings client bound to one edit.
  PlayListingsApi({
    required play.AndroidPublisherApi api,
    required this.packageName,
    required this.editId,
    PlayApiGuard? guard,
  }) : _api = api,
       _guard = guard ?? PlayApiGuard();

  /// The app's application ID.
  final String packageName;

  /// The open edit changes are staged in.
  final String editId;

  final play.AndroidPublisherApi _api;
  final PlayApiGuard _guard;

  /// Every listing the app has, as the edit currently sees it.
  Future<List<PlayListing>> list() async {
    final response = await _guard.run(
      'listings.list',
      () => _api.edits.listings.list(packageName, editId),
    );
    return [
      for (final listing in response.listings ?? const <play.Listing>[])
        PlayListing.fromApi(listing),
    ];
  }

  /// The listing for [language], or `null` if the app has none.
  ///
  /// Implemented over [list] rather than `listings.get`, which answers `404`
  /// for a locale with no listing. That is indistinguishable from the `404`
  /// an expired edit produces, and silently treating a dead edit as "no
  /// listing yet" would turn a failed run into one that reports success
  /// having published nothing.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[language]**: The locale, as Google Play spells it.
  Future<PlayListing?> get(String language) async {
    for (final listing in await list()) {
      if (listing.language == language) return listing;
    }
    return null;
  }

  /// Writes [listing], replacing that locale's text entirely.
  ///
  /// `listings.update` is a whole-object write: fields left `null` on
  /// [listing] are cleared on the store, not left alone. Use
  /// `PlayListing.merge` against what [get] returns to send a partial update.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[listing]**: The text to write. Its `language` names the locale.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final local = const PlayListing(language: 'ja-JP', title: '家計簿');
  /// await session.listings.update(local.merge(await api.get('ja-JP')));
  /// ```
  Future<PlayListing> update(PlayListing listing) async {
    if (listing.language.isEmpty) {
      throw ArgumentError.value(
        listing.language,
        'listing.language',
        'A listing needs a locale to be written to',
      );
    }
    final response = await _guard.run(
      'listings.update (${listing.language})',
      () => _api.edits.listings.update(
        listing.toApi(),
        packageName,
        editId,
        listing.language,
      ),
    );
    return PlayListing.fromApi(response);
  }

  /// Removes the listing for [language].
  ///
  /// Destructive, and not reachable from the publisher: nothing about a local
  /// metadata directory implies a locale should stop existing on the store.
  /// Call it deliberately or not at all.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[language]**: The locale to remove.
  Future<void> delete(String language) => _guard.run(
    'listings.delete ($language)',
    () => _api.edits.listings.delete(packageName, editId, language),
  );

  /// Removes **every** listing the app has, in every locale.
  ///
  /// There is no local state that justifies calling this automatically: a
  /// metadata directory holding five locales says nothing about a sixth that
  /// was translated in Play Console. It exists because the API has it, and
  /// because a caller rebuilding a listing from scratch may genuinely want
  /// it. Nothing in this package calls it for you.
  Future<void> deleteAll() => _guard.run(
    'listings.deleteall',
    () => _api.edits.listings.deleteall(packageName, editId),
  );
}
