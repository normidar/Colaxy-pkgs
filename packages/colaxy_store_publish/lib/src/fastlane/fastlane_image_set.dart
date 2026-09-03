import 'dart:io';

import 'package:colaxy_store_publish/src/google_play/play_image_type.dart';
import 'package:meta/meta.dart';

/// The image files found for one locale and one store slot.
///
/// The directory names under `<locale>/images/` are already the `imageType`
/// values Google Play expects, so [imageType] comes from the path rather than
/// from a lookup table.
///
/// ## Parameters
///
/// ### Required
/// - **[locale]**: The locale directory the images were found under.
/// - **[imageType]**: The slot they belong in.
/// - **[files]**: The images, in upload order.
///
/// ## Example
///
/// ```dart
/// for (final set in metadata.imageSets('ja-JP')) {
///   print('${set.imageType.wireName}: ${set.files.length} files');
/// }
/// ```
@immutable
class FastlaneImageSet {
  /// Creates an image set.
  const FastlaneImageSet({
    required this.locale,
    required this.imageType,
    required this.files,
  });

  /// The locale directory the images were found under.
  final String locale;

  /// The slot the images belong in.
  final PlayImageType imageType;

  /// The images, in the order they will be uploaded.
  ///
  /// Sorted by file name. Google Play shows screenshots in upload order and
  /// offers no way to reorder them through the API, so the file names are the
  /// only control a caller has over the sequence — `01.png`, `02.png` and so
  /// on order correctly, `1.png` … `10.png` does not.
  final List<File> files;

  /// Whether the set holds no images.
  bool get isEmpty => files.isEmpty;

  @override
  String toString() =>
      'FastlaneImageSet($locale/${imageType.wireName}, ${files.length} files)';
}
