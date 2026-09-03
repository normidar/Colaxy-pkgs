import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/fastlane/fastlane_image_set.dart';
import 'package:colaxy_store_publish/src/fastlane/fastlane_metadata.dart';
import 'package:colaxy_store_publish/src/google_play/play_edit_session.dart';
import 'package:colaxy_store_publish/src/google_play/play_image_type.dart';
import 'package:colaxy_store_publish/src/google_play/play_listing.dart';
import 'package:colaxy_store_publish/src/publish/play_publish_options.dart';
import 'package:colaxy_store_publish/src/publish/play_publish_report.dart';

/// Stages a fastlane metadata directory into an open edit.
///
/// This is the piece that replaces `fastlane supply`'s metadata and image
/// handling. It reads files, calls the store, and reports what it did — and
/// deliberately stops there. **It never commits.** The caller holds the
/// session and decides whether the staged result is worth publishing, which
/// is the whole reason Google Play's edits are worth having.
///
/// ## Parameters
///
/// ### Required
/// - **[metadata]**: The metadata directory to read.
///
/// ### Optional
/// - **[options]**: What to publish and what to leave alone (default:
///   `PlayPublishOptions()`).
/// - **[onLog]**: Receives one line per locale and slot (default: `null`,
///   logging nothing).
///
/// ## Example
///
/// ```dart
/// final publisher = PlayMetadataPublisher(
///   metadata: FastlaneMetadata.forProject('.'),
/// );
/// final report = await publisher.publish(session);
/// if (report.isEmpty) {
///   await session.discard();
/// } else {
///   await session.commit();
/// }
/// ```
class PlayMetadataPublisher {
  /// Creates a publisher over one metadata directory.
  PlayMetadataPublisher({
    required this.metadata,
    this.options = const PlayPublishOptions(),
    this.onLog,
  });

  /// The metadata directory to read.
  final FastlaneMetadata metadata;

  /// What to publish and what to leave alone.
  final PlayPublishOptions options;

  /// Receives one line per locale and slot.
  final StoreConsoleLog? onLog;

  /// Stages every selected locale into [session].
  ///
  /// Listings are merged against what the store already has, so a locale
  /// directory holding only `title.txt` updates the title and leaves the
  /// descriptions intact — `listings.update` would otherwise clear them,
  /// since it replaces the whole listing.
  ///
  /// The store's listings are read once, not once per locale.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[session]**: An open edit. Left open when this returns.
  Future<PlayPublishReport> publish(PlayEditSession session) async {
    if (!session.isOpen) {
      throw StateError(
        'Cannot publish into edit ${session.editId}: it was already '
        '${session.state.name}.',
      );
    }

    final requested = options.locales;
    final available = metadata.locales().toSet();
    final selected = <String>[
      for (final locale in requested ?? available)
        if (available.contains(locale) && options.includes(locale)) locale,
    ]..sort();
    final skipped = <String>[
      for (final locale in requested ?? const <String>[])
        if (!available.contains(locale)) locale,
    ];

    // Read once. Every locale needs the current listing to merge against, and
    // asking per locale would be one request each for no extra information.
    final current = <String, PlayListing>{};
    if (options.publishListings) {
      for (final listing in await session.listings.list()) {
        current[listing.language] = listing;
      }
    }

    final updated = <String>[];
    final uploaded = <String, Map<PlayImageType, int>>{};
    final deleted = <String, Map<PlayImageType, int>>{};

    for (final locale in selected) {
      final listing = metadata.listing(locale);
      var touched = false;

      if (options.publishListings && !listing.toPlayListing().isEmpty) {
        final merged = listing.toPlayListing().merge(current[locale]);
        await session.listings.update(merged);
        updated.add(locale);
        touched = true;
        onLog?.call('updated listing for $locale');
      }

      if (options.publishImages) {
        final counts = await _publishImages(session, locale, deleted);
        if (counts.isNotEmpty) {
          uploaded[locale] = counts;
          touched = true;
        }
      }

      if (!touched) skipped.add(locale);
    }

    skipped.sort();
    return PlayPublishReport(
      updatedLocales: updated,
      uploadedImages: uploaded,
      deletedImages: deleted,
      skippedLocales: skipped,
    );
  }

  /// Uploads every image set for [locale], recording deletions in [deleted].
  Future<Map<PlayImageType, int>> _publishImages(
    PlayEditSession session,
    String locale,
    Map<String, Map<PlayImageType, int>> deleted,
  ) async {
    final counts = <PlayImageType, int>{};
    final sets = [
      ...metadata.imageSets(locale),
      if (options.uploadStrayFeatureGraphic) ..._strayFeatureGraphic(locale),
    ];

    for (final set in sets) {
      // Uploads append to a multi-image slot, so replacing one means
      // emptying it first. Single-image slots are replaced by Google on
      // upload, and deleting first would only widen the window in which the
      // listing has no feature graphic at all.
      if (options.replaceScreenshots && set.imageType.holdsMany) {
        final removed = await session.images.deleteAll(
          language: locale,
          imageType: set.imageType,
        );
        if (removed > 0) {
          (deleted[locale] ??= {})[set.imageType] = removed;
          onLog?.call(
            'emptied $locale/${set.imageType.wireName} ($removed images)',
          );
        }
      }

      for (final file in set.files) {
        await session.images.upload(
          language: locale,
          imageType: set.imageType,
          file: file,
          aiGeneratedState: options.aiGeneratedState,
        );
      }
      counts[set.imageType] = set.files.length;
      onLog?.call(
        'uploaded ${set.files.length} to $locale/${set.imageType.wireName}',
      );
    }
    return counts;
  }

  /// The locale-independent feature graphic, as a set for [locale].
  ///
  /// Empty unless the file exists and a per-locale feature graphic does not:
  /// a project that has both meant the per-locale one.
  Iterable<FastlaneImageSet> _strayFeatureGraphic(String locale) sync* {
    final stray = metadata.strayFeatureGraphic;
    if (stray == null) return;
    final hasPerLocale = metadata
        .imageSets(locale)
        .any((set) => set.imageType == PlayImageType.featureGraphic);
    if (hasPerLocale) return;
    yield FastlaneImageSet(
      locale: locale,
      imageType: PlayImageType.featureGraphic,
      files: [stray],
    );
  }
}
