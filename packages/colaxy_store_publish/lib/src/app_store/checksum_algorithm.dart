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
/// **The specification lists two values and the store accepts one.**
/// Committing a build upload with `SHA_256` fails
/// `ENTITY_ERROR.ATTRIBUTE.INVALID`; the identical request with `MD5` is
/// accepted. Verified against a real account, so `MD5` is the default
/// everywhere here.
enum ChecksumAlgorithm {
  /// MD5. The only value observed to work, on screenshots and on builds.
  md5('MD5'),

  /// SHA-256. In the specification's enum, **rejected by the store** for
  /// `sourceFileChecksums`. Kept because the enum has it, not because it
  /// works.
  sha256('SHA_256');

  /// Creates an algorithm with the wire name App Store Connect uses.
  const ChecksumAlgorithm(this.wireName);

  /// The value App Store Connect expects in a `Checksums` object.
  final String wireName;
}
