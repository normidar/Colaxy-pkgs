import 'package:colaxy_store_publish/src/google_play/play_image_type.dart';
import 'package:meta/meta.dart';

/// What a publish actually staged in the edit.
///
/// Worth reading rather than discarding: a run that finds no metadata
/// directory for the locales it was given succeeds, uploads nothing, and
/// would otherwise be indistinguishable from a run that worked. [isEmpty]
/// is the check for that.
///
/// These are staged changes, not published ones. Nothing here reached the
/// store until the edit was committed.
///
/// ## Parameters
///
/// ### Optional
/// - **[updatedLocales]**: Locales whose listing text was written
///   (default: empty).
/// - **[uploadedImages]**: How many images were uploaded, per locale and
///   slot (default: empty).
/// - **[deletedImages]**: How many images were deleted to make room, per
///   locale and slot (default: empty).
/// - **[skippedLocales]**: Locales that were asked for and not found, or that
///   held nothing to publish (default: empty).
@immutable
class PlayPublishReport {
  /// Creates a report.
  const PlayPublishReport({
    this.updatedLocales = const [],
    this.uploadedImages = const {},
    this.deletedImages = const {},
    this.skippedLocales = const [],
  });

  /// Locales whose listing text was written.
  final List<String> updatedLocales;

  /// How many images were uploaded, keyed by locale then slot.
  final Map<String, Map<PlayImageType, int>> uploadedImages;

  /// How many images were deleted to make room, keyed by locale then slot.
  ///
  /// Only ever non-empty when `PlayPublishOptions.replaceScreenshots` was on.
  final Map<String, Map<PlayImageType, int>> deletedImages;

  /// Locales that were asked for and not found, or that held nothing.
  final List<String> skippedLocales;

  /// Total images uploaded across every locale and slot.
  int get imageCount => uploadedImages.values
      .expand((slots) => slots.values)
      .fold(0, (sum, count) => sum + count);

  /// Total images deleted across every locale and slot.
  int get deletedImageCount => deletedImages.values
      .expand((slots) => slots.values)
      .fold(0, (sum, count) => sum + count);

  /// Whether nothing at all was staged.
  ///
  /// A commit after an empty publish is not harmless: it still cancels any
  /// review in progress under Google's default behaviour. Check this before
  /// committing an automated run.
  bool get isEmpty => updatedLocales.isEmpty && imageCount == 0;

  @override
  String toString() {
    final parts = <String>[
      '${updatedLocales.length} listings',
      '$imageCount images',
      if (deletedImageCount > 0) '$deletedImageCount deleted',
      if (skippedLocales.isNotEmpty) '${skippedLocales.length} skipped',
    ];
    return 'PlayPublishReport(${parts.join(', ')})';
  }
}
