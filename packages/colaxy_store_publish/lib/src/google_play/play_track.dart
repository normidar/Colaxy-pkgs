import 'package:colaxy_store_publish/src/google_play/play_track_release.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:meta/meta.dart';

/// A Google Play release track and the releases currently on it.
///
/// ## Parameters
///
/// ### Required
/// - **[name]**: The track identifier, e.g. `internal` or `production`.
///
/// ### Optional
/// - **[releases]**: The releases on the track (default: empty).
///
/// ## Example
///
/// ```dart
/// final track = await session.tracks.get(PlayTrack.internal);
/// ```
@immutable
class PlayTrack {
  /// Creates a track.
  const PlayTrack({required this.name, this.releases = const []});

  /// Reads a track out of an `androidpublisher` response.
  @internal
  factory PlayTrack.fromApi(play.Track source) => PlayTrack(
    name: source.track ?? '',
    releases: [
      for (final release in source.releases ?? const <play.TrackRelease>[])
        PlayTrackRelease.fromApi(release),
    ],
  );

  /// The internal testing track.
  static const internal = 'internal';

  /// The closed testing track.
  static const alpha = 'alpha';

  /// The open testing track.
  static const beta = 'beta';

  /// The production track.
  static const production = 'production';

  /// The track identifier.
  ///
  /// Passed to the API verbatim. Beyond the four well-known names above, an
  /// app can have custom closed-testing tracks and form-factor tracks such as
  /// `wear:production`, so this is a string rather than an enum.
  final String name;

  /// The releases currently on the track.
  final List<PlayTrackRelease> releases;

  /// This track with [release] added, replacing any release it supersedes.
  ///
  /// `tracks.update` replaces a track's entire release list, so sending a
  /// track carrying only the new release silently removes the others — an
  /// app with a halted rollout and a completed release loses one of them.
  /// This merges instead: releases that share a version code with [release]
  /// are dropped, and everything else is kept.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[release]**: The release to add.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final next = current.withRelease(
  ///   const PlayTrackRelease(versionCodes: [412]),
  /// );
  /// ```
  PlayTrack withRelease(PlayTrackRelease release) {
    final incoming = release.versionCodes.toSet();
    return PlayTrack(
      name: name,
      releases: [
        for (final existing in releases)
          if (!existing.versionCodes.any(incoming.contains)) existing,
        release,
      ],
    );
  }

  /// This track as the body `androidpublisher` expects.
  @internal
  play.Track toApi() => play.Track(
    track: name,
    releases: [
      for (final release in releases) release.toApi(),
    ],
  );

  @override
  String toString() => 'PlayTrack($name, ${releases.length} releases)';
}
