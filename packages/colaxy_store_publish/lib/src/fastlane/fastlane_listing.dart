import 'package:colaxy_store_publish/src/google_play/play_listing.dart';
import 'package:meta/meta.dart';

/// One locale's text as it sits on disk under the fastlane metadata tree.
///
/// The mapping to a store listing needs no table:
///
/// | file                     | field              |
/// |--------------------------|--------------------|
/// | `title.txt`              | `title`            |
/// | `short_description.txt`  | `shortDescription` |
/// | `full_description.txt`   | `fullDescription`  |
/// | `video.txt`              | `video`            |
/// | `changelogs/*.txt`       | a release's notes  |
///
/// A file that is absent leaves the corresponding field `null`, which means
/// "do not touch what the store has" — not "clear it". See
/// `PlayListing.merge`.
///
/// ## Parameters
///
/// ### Required
/// - **[locale]**: The directory name, which is also the locale sent to
///   Google Play.
///
/// ### Optional
/// - **[title]**: Contents of `title.txt` (default: `null`).
/// - **[shortDescription]**: Contents of `short_description.txt`
///   (default: `null`).
/// - **[fullDescription]**: Contents of `full_description.txt`
///   (default: `null`).
/// - **[video]**: Contents of `video.txt` (default: `null`).
/// - **[changelogs]**: Contents of `changelogs/`, keyed by file stem
///   (default: empty).
@immutable
class FastlaneListing {
  /// Creates a listing read from disk.
  const FastlaneListing({
    required this.locale,
    this.title,
    this.shortDescription,
    this.fullDescription,
    this.video,
    this.changelogs = const {},
  });

  /// The file stem `fastlane supply` treats as the fallback changelog.
  static const defaultChangelogKey = 'default';

  /// The directory name, used verbatim as the Google Play locale.
  ///
  /// No normalisation happens here. Google Play's accepted locale list is
  /// not identical to the App Store's, nor to Flutter's, and a mapping table
  /// baked into this package would go stale silently. A locale Play does not
  /// accept comes back as an error naming it.
  final String locale;

  /// The app's name on the listing.
  final String? title;

  /// The one-line summary.
  final String? shortDescription;

  /// The long description.
  final String? fullDescription;

  /// A promotional YouTube URL.
  final String? video;

  /// Changelog text keyed by file stem.
  ///
  /// `fastlane supply` names these after the version code they belong to —
  /// `changelogs/412.txt` — with `changelogs/default.txt` as the fallback for
  /// any version code with no file of its own. Both are kept here so
  /// [changelogFor] can pick.
  final Map<String, String> changelogs;

  /// Whether the locale directory held nothing this package can publish.
  bool get isEmpty =>
      title == null &&
      shortDescription == null &&
      fullDescription == null &&
      video == null &&
      changelogs.isEmpty;

  /// The changelog for [versionCode], falling back to `default.txt`.
  ///
  /// Passing `null` asks for the fallback directly, which is what a metadata
  /// push with no bundle wants.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[versionCode]**: The version code being released, or `null`.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final notes = listing.changelogFor(bundle.versionCode);
  /// ```
  String? changelogFor(int? versionCode) {
    if (versionCode != null) {
      final exact = changelogs['$versionCode'];
      if (exact != null) return exact;
    }
    return changelogs[defaultChangelogKey];
  }

  /// This listing as the text half of a store listing.
  ///
  /// Changelogs are deliberately not carried over: they belong to a release
  /// on a track, not to the listing, and Google Play stores them in a
  /// different place.
  PlayListing toPlayListing() => PlayListing(
    language: locale,
    title: title,
    shortDescription: shortDescription,
    fullDescription: fullDescription,
    video: video,
  );

  @override
  String toString() => 'FastlaneListing($locale)';
}
