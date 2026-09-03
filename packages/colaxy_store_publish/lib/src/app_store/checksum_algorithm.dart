/// How a checksum handed to App Store Connect was computed.
///
/// Only build uploads take this. A screenshot's `sourceFileChecksum` is a
/// bare string with no algorithm beside it — Apple decides what it means, and
/// MD5 is what works there. Build uploads use a `Checksums` object that names
/// the algorithm, so the choice becomes real.
///
/// ## Example
///
/// ```dart
/// await uploader.upload(ipa, operations, algorithm: ChecksumAlgorithm.sha256);
/// ```
enum ChecksumAlgorithm {
  /// MD5. What screenshot uploads use, and still accepted for builds.
  md5('MD5'),

  /// SHA-256. The stronger of the two Apple accepts for a build.
  sha256('SHA_256');

  /// Creates an algorithm with the wire name App Store Connect uses.
  const ChecksumAlgorithm(this.wireName);

  /// The value App Store Connect expects in a `Checksums` object.
  final String wireName;
}
