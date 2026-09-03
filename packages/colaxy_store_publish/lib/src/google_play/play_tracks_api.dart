import 'package:colaxy_store_publish/src/google_play/play_api_guard.dart';
import 'package:colaxy_store_publish/src/google_play/play_release_status.dart';
import 'package:colaxy_store_publish/src/google_play/play_track.dart';
import 'package:colaxy_store_publish/src/google_play/play_track_release.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;

/// The release tracks inside one open edit.
///
/// A track update is what actually ships a bundle to users, so this is the
/// class where committing an edit stops being reversible. Uploading a bundle
/// and never touching a track leaves it visible in Play Console and served to
/// nobody.
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
/// await session.tracks.release(
///   track: PlayTrack.internal,
///   versionCodes: [bundle.versionCode!],
/// );
/// ```
class PlayTracksApi {
  /// Creates a tracks client bound to one edit.
  PlayTracksApi({
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

  /// Every track the app has, as the edit currently sees it.
  Future<List<PlayTrack>> list() async {
    final response = await _guard.run(
      'tracks.list',
      () => _api.edits.tracks.list(packageName, editId),
    );
    return [
      for (final track in response.tracks ?? const <play.Track>[])
        PlayTrack.fromApi(track),
    ];
  }

  /// The track called [name], or `null` if the app has no such track.
  ///
  /// Implemented over [list] for the same reason the listings client is: a
  /// `404` from `tracks.get` cannot be told apart from the `404` of an edit
  /// that has expired.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[name]**: The track identifier.
  Future<PlayTrack?> get(String name) async {
    for (final track in await list()) {
      if (track.name == name) return track;
    }
    return null;
  }

  /// Writes [track], replacing its entire release list.
  ///
  /// Prefer [release], which reads the track first and merges. This is the
  /// unguarded form, for callers who have already assembled the full list.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[track]**: The track to write.
  Future<PlayTrack> update(PlayTrack track) async {
    for (final release in track.releases) {
      if (!release.isRolloutConsistent) {
        throw ArgumentError.value(
          release.userFraction,
          'release.userFraction',
          'A release with status "${release.status.wireName}" needs a '
              'userFraction strictly between 0 and 1',
        );
      }
    }
    final response = await _guard.run(
      'tracks.update (${track.name})',
      () => _api.edits.tracks.update(
        track.toApi(),
        packageName,
        editId,
        track.name,
      ),
    );
    return PlayTrack.fromApi(response);
  }

  /// Puts [versionCodes] on [track], keeping the releases already there.
  ///
  /// Reads the track first and merges, because `tracks.update` replaces the
  /// whole release list: sending only the new release would drop a halted
  /// rollout or a still-serving older release from the track.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[track]**: The track identifier, e.g. `PlayTrack.internal`.
  /// - **[versionCodes]**: The bundles this release serves.
  ///
  /// ### Optional
  /// - **[status]**: How far to roll it out (default:
  ///   [PlayReleaseStatus.completed], which serves it to everyone).
  /// - **[userFraction]**: Share of users for a staged rollout (default:
  ///   `null`; required when [status] is [PlayReleaseStatus.inProgress]).
  /// - **[releaseNotes]**: Changelog text keyed by locale (default: empty).
  /// - **[name]**: The release name in Play Console (default: `null`).
  /// - **[inAppUpdatePriority]**: 0 to 5 (default: `null`).
  ///
  /// ## Example
  ///
  /// ```dart
  /// // A 10% staged rollout to production.
  /// await session.tracks.release(
  ///   track: PlayTrack.production,
  ///   versionCodes: [412],
  ///   status: PlayReleaseStatus.inProgress,
  ///   userFraction: 0.1,
  /// );
  /// ```
  Future<PlayTrack> release({
    required String track,
    required List<int> versionCodes,
    PlayReleaseStatus status = PlayReleaseStatus.completed,
    double? userFraction,
    Map<String, String> releaseNotes = const {},
    String? name,
    int? inAppUpdatePriority,
  }) async {
    if (versionCodes.isEmpty) {
      throw ArgumentError.value(
        versionCodes,
        'versionCodes',
        'A release needs at least one version code',
      );
    }
    final current = await get(track) ?? PlayTrack(name: track);
    return update(
      current.withRelease(
        PlayTrackRelease(
          versionCodes: versionCodes,
          status: status,
          userFraction: userFraction,
          releaseNotes: releaseNotes,
          name: name,
          inAppUpdatePriority: inAppUpdatePriority,
        ),
      ),
    );
  }
}
