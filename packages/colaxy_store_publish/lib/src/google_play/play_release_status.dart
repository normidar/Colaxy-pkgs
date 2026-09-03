/// How far a release on a track has been rolled out.
///
/// The API has a sixth value, `statusUnspecified`, which is what a release
/// reads back as when the field was never set. It is omitted here because
/// sending it is never the right thing to do.
///
/// ## Example
///
/// ```dart
/// // A staged rollout to 10% of users.
/// const status = PlayReleaseStatus.inProgress;
/// ```
enum PlayReleaseStatus {
  /// Uploaded but not served to anyone.
  ///
  /// The release shows in Play Console and can be promoted later. This is the
  /// safe status to publish under while a run is still being trusted.
  draft('draft'),

  /// Served to the fraction of users named by `userFraction`.
  ///
  /// Google requires a fraction strictly between 0 and 1 for this status.
  inProgress('inProgress'),

  /// Stopped. Users who already have the APKs keep them.
  halted('halted'),

  /// Served to everyone eligible, with no further changes planned.
  completed('completed');

  /// Creates a status with the wire name Google Play uses for it.
  const PlayReleaseStatus(this.wireName);

  /// The value `androidpublisher` expects in `TrackRelease.status`.
  final String wireName;

  /// The status [wireName] refers to, or `null` if it names no status.
  ///
  /// `statusUnspecified` maps to `null`, which is the honest answer: the
  /// release has no status this package can act on.
  static PlayReleaseStatus? byWireName(String wireName) {
    for (final status in values) {
      if (status.wireName == wireName) return status;
    }
    return null;
  }

  /// Whether this status requires `userFraction` to be set.
  bool get needsUserFraction => this == PlayReleaseStatus.inProgress;
}
