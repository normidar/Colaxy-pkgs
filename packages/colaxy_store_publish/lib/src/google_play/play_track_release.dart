import 'package:colaxy_store_publish/src/google_play/play_release_status.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:meta/meta.dart';

/// One release on a Google Play track.
///
/// A track holds a list of these, and updating a track replaces that whole
/// list. Sending a track with one release therefore *removes* the others,
/// which is the single most surprising thing about this API — hence
/// `PlayTrack.withRelease`, which merges rather than replaces.
///
/// [versionCodes] has the same shape of trap: the API's own documentation
/// says it "must include version codes to retain from previous releases", so
/// a release listing only the new bundle drops the old ones from that
/// release.
///
/// ## Parameters
///
/// ### Required
/// - **[versionCodes]**: Every version code this release serves.
///
/// ### Optional
/// - **[status]**: How far it is rolled out (default:
///   [PlayReleaseStatus.completed]).
/// - **[name]**: The release name in Play Console (default: `null`, letting
///   Google generate one from the version name).
/// - **[releaseNotes]**: Changelog text keyed by locale (default: empty).
/// - **[userFraction]**: Share of users for a staged rollout (default:
///   `null`; required when [status] is [PlayReleaseStatus.inProgress]).
/// - **[inAppUpdatePriority]**: 0 to 5, higher being more urgent (default:
///   `null`, which Google treats as 0).
///
/// ## Example
///
/// ```dart
/// const release = PlayTrackRelease(
///   versionCodes: [412],
///   status: PlayReleaseStatus.inProgress,
///   userFraction: 0.1,
/// );
/// ```
@immutable
class PlayTrackRelease {
  /// Creates a release.
  const PlayTrackRelease({
    required this.versionCodes,
    this.status = PlayReleaseStatus.completed,
    this.name,
    this.releaseNotes = const {},
    this.userFraction,
    this.inAppUpdatePriority,
  });

  /// Reads a release out of an `androidpublisher` response.
  @internal
  factory PlayTrackRelease.fromApi(play.TrackRelease source) {
    final notes = <String, String>{};
    for (final note in source.releaseNotes ?? const <play.LocalizedText>[]) {
      final language = note.language;
      final text = note.text;
      if (language != null && text != null) notes[language] = text;
    }
    return PlayTrackRelease(
      versionCodes:
          source.versionCodes
              ?.map(int.tryParse)
              .whereType<int>()
              .toList(growable: false) ??
          const [],
      status:
          PlayReleaseStatus.byWireName(source.status ?? '') ??
          PlayReleaseStatus.completed,
      name: source.name,
      releaseNotes: notes,
      userFraction: source.userFraction,
      inAppUpdatePriority: source.inAppUpdatePriority,
    );
  }

  /// Every version code this release serves.
  ///
  /// Sent as strings, because the API types them as strings even though they
  /// are integers in the manifest.
  final List<int> versionCodes;

  /// How far the release is rolled out.
  final PlayReleaseStatus status;

  /// The release name shown in Play Console.
  final String? name;

  /// Changelog text keyed by locale.
  ///
  /// The keys are the same locale strings as a listing's `language`, so the
  /// `changelogs/` files under a locale directory land here unchanged.
  final Map<String, String> releaseNotes;

  /// Share of users eligible for a staged rollout, strictly between 0 and 1.
  final double? userFraction;

  /// In-app update priority, 0 to 5.
  final int? inAppUpdatePriority;

  /// Whether [userFraction] is consistent with [status].
  ///
  /// Checked locally because it is a rule about this object rather than about
  /// the store: Google's own documentation states the constraint, and the
  /// failure it produces otherwise ("invalid release") does not say which
  /// field was wrong.
  bool get isRolloutConsistent {
    if (status.needsUserFraction) {
      final fraction = userFraction;
      return fraction != null && fraction > 0 && fraction < 1;
    }
    return true;
  }

  /// This release as the body `androidpublisher` expects.
  @internal
  play.TrackRelease toApi() => play.TrackRelease(
    versionCodes: versionCodes.map((code) => '$code').toList(growable: false),
    status: status.wireName,
    name: name,
    userFraction: userFraction,
    inAppUpdatePriority: inAppUpdatePriority,
    releaseNotes: releaseNotes.isEmpty
        ? null
        : [
            for (final entry in releaseNotes.entries)
              play.LocalizedText(language: entry.key, text: entry.value),
          ],
  );

  @override
  String toString() =>
      'PlayTrackRelease($versionCodes, ${status.wireName})';
}
