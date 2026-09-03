import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:meta/meta.dart';

/// An Android App Bundle attached to an edit.
///
/// [versionCode] is the value that matters downstream: it is what a track
/// release refers to, and what names the changelog file
/// `changelogs/<versionCode>.txt` under the fastlane metadata directory.
///
/// Google reads the version code out of the bundle's own manifest rather than
/// taking it from the request, so an upload is also how you find out which
/// version code you just built.
///
/// ## Parameters
///
/// ### Optional
/// - **[versionCode]**: The bundle's version code (default: `null`).
/// - **[sha256]**: SHA-256 of the uploaded bytes (default: `null`).
/// - **[sha1]**: SHA-1 of the uploaded bytes (default: `null`).
@immutable
class PlayBundle {
  /// Creates a bundle record.
  const PlayBundle({this.versionCode, this.sha256, this.sha1});

  /// Reads a bundle out of an `androidpublisher` response.
  @internal
  factory PlayBundle.fromApi(play.Bundle source) => PlayBundle(
    versionCode: source.versionCode,
    sha256: source.sha256,
    sha1: source.sha1,
  );

  /// The version code from the bundle's base module manifest.
  final int? versionCode;

  /// SHA-256 of the uploaded bytes, as a hex string.
  final String? sha256;

  /// SHA-1 of the uploaded bytes, as a hex string.
  final String? sha1;

  @override
  String toString() => 'PlayBundle(versionCode: ${versionCode ?? '?'})';
}
