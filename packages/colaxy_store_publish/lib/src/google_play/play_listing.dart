import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:meta/meta.dart';

/// One locale's text on a Google Play store listing.
///
/// The four text fields map one-to-one onto the files `colaxy_localization`
/// writes under `fastlane/metadata/android/<locale>/`, which is why no
/// translation table exists anywhere in this package.
///
/// A `null` field means "leave whatever is on the store alone". An empty
/// string means "clear it". The distinction matters: `listings.update`
/// replaces the whole listing, so a field omitted from a request is cleared
/// on the store, and this class exists partly to make that failure mode hard
/// to hit by accident — see [merge].
///
/// ## Parameters
///
/// ### Required
/// - **[language]**: The locale, as Google Play spells it (a BCP-47 tag such
///   as `de-AT` or `ja-JP`).
///
/// ### Optional
/// - **[title]**: The app's name on the listing (default: `null`).
/// - **[shortDescription]**: The one-line summary (default: `null`).
/// - **[fullDescription]**: The long description (default: `null`).
/// - **[video]**: A promotional YouTube URL (default: `null`).
///
/// ## Example
///
/// ```dart
/// const listing = PlayListing(
///   language: 'ja-JP',
///   title: '家計簿アプリ',
///   shortDescription: 'レシートを撮るだけ',
/// );
/// ```
@immutable
class PlayListing {
  /// Creates a listing for one locale.
  const PlayListing({
    required this.language,
    this.title,
    this.shortDescription,
    this.fullDescription,
    this.video,
  });

  /// Reads a listing out of an `androidpublisher` response.
  @internal
  factory PlayListing.fromApi(play.Listing source) => PlayListing(
    language: source.language ?? '',
    title: source.title,
    shortDescription: source.shortDescription,
    fullDescription: source.fullDescription,
    video: source.video,
  );

  /// The locale, as Google Play spells it.
  ///
  /// Passed to the API verbatim. This package does not carry a table of
  /// which locales Play accepts: the list changes, and a stale local copy
  /// would reject locales that in fact work. An unsupported locale comes back
  /// as an error from Google.
  final String language;

  /// The app's name on this listing.
  final String? title;

  /// The one-line summary shown under the title.
  final String? shortDescription;

  /// The long description.
  final String? fullDescription;

  /// A promotional YouTube URL.
  final String? video;

  /// Whether every text field is unset.
  bool get isEmpty =>
      title == null &&
      shortDescription == null &&
      fullDescription == null &&
      video == null;

  /// This listing's fields laid over [current], which came from the store.
  ///
  /// `listings.update` is a whole-object write, so publishing a listing that
  /// only sets `title` would blank the descriptions. Merging against what the
  /// store already has turns a partial local listing into a partial update,
  /// which is what a caller supplying only some files means.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[current]**: The listing as it is on the store, or `null` when the
  ///   locale has no listing yet.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final merged = local.merge(await session.listings.get('ja-JP'));
  /// ```
  PlayListing merge(PlayListing? current) {
    if (current == null) return this;
    return PlayListing(
      language: language,
      title: title ?? current.title,
      shortDescription: shortDescription ?? current.shortDescription,
      fullDescription: fullDescription ?? current.fullDescription,
      video: video ?? current.video,
    );
  }

  /// This listing as the request body `androidpublisher` expects.
  @internal
  play.Listing toApi() => play.Listing(
    language: language,
    title: title,
    shortDescription: shortDescription,
    fullDescription: fullDescription,
    video: video,
  );

  @override
  bool operator ==(Object other) =>
      other is PlayListing &&
      other.language == language &&
      other.title == title &&
      other.shortDescription == shortDescription &&
      other.fullDescription == fullDescription &&
      other.video == video;

  @override
  int get hashCode =>
      Object.hash(language, title, shortDescription, fullDescription, video);

  @override
  String toString() => 'PlayListing($language)';
}
