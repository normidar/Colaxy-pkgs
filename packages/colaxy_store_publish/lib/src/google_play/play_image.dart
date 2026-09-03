import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:meta/meta.dart';

/// An image already attached to a listing.
///
/// Returned by uploads and listings of an image slot. The hashes are the
/// reason this type is worth having: comparing the local file's SHA-256
/// against [sha256] is how a re-run can tell "already uploaded" from "changed
/// and needs replacing", without downloading anything.
///
/// ## Parameters
///
/// ### Optional
/// - **[id]**: Google's identifier for the image (default: `null`).
/// - **[url]**: A URL serving a preview (default: `null`).
/// - **[sha256]**: SHA-256 of the uploaded bytes (default: `null`).
/// - **[sha1]**: SHA-1 of the uploaded bytes (default: `null`).
@immutable
class PlayImage {
  /// Creates an image record.
  const PlayImage({this.id, this.url, this.sha256, this.sha1});

  /// Reads an image out of an `androidpublisher` response.
  @internal
  factory PlayImage.fromApi(play.Image source) => PlayImage(
    id: source.id,
    url: source.url,
    sha256: source.sha256,
    sha1: source.sha1,
  );

  /// Google's identifier for the image, used to delete it individually.
  final String? id;

  /// A URL serving a preview of the image.
  final String? url;

  /// SHA-256 of the uploaded bytes, as a hex string.
  final String? sha256;

  /// SHA-1 of the uploaded bytes, as a hex string.
  final String? sha1;

  @override
  String toString() => 'PlayImage(${id ?? '?'})';
}
