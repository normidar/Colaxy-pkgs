import 'package:colaxy_store_publish/src/app_store/screenshot_display_type.dart';
import 'package:meta/meta.dart';

/// What an App Store publish actually wrote.
///
/// **Unlike the Google Play report, this describes changes that are already
/// live.** There is no edit to discard and no commit to withhold, so a
/// partial run leaves a partially updated store — which is why
/// [failedLocales] exists and why it is worth reading rather than discarding.
///
/// ## Parameters
///
/// ### Optional
/// - **[appInfoLocales]**: Locales whose app-wide text was written.
/// - **[versionLocales]**: Locales whose version-scoped text was written.
/// - **[uploadedScreenshots]**: How many screenshots were uploaded, per
///   locale and slot.
/// - **[deletedScreenshots]**: How many were removed to make room.
/// - **[unmappedScreenshots]**: Files skipped for want of a device mapping.
/// - **[skippedLocales]**: Locales asked for and not found, or with nothing
///   to publish.
/// - **[failedLocales]**: Locales that failed partway, with the reason.
@immutable
class AppStorePublishReport {
  /// Creates a report.
  const AppStorePublishReport({
    this.appInfoLocales = const [],
    this.versionLocales = const [],
    this.uploadedScreenshots = const {},
    this.deletedScreenshots = const {},
    this.unmappedScreenshots = const [],
    this.skippedLocales = const [],
    this.failedLocales = const {},
  });

  /// Locales whose app-wide text was written.
  final List<String> appInfoLocales;

  /// Locales whose version-scoped text was written.
  final List<String> versionLocales;

  /// How many screenshots were uploaded, keyed by locale then slot.
  final Map<String, Map<ScreenshotDisplayType, int>> uploadedScreenshots;

  /// How many screenshots were removed, keyed by locale then slot.
  final Map<String, Map<ScreenshotDisplayType, int>> deletedScreenshots;

  /// Screenshot paths skipped because no device slot could be derived.
  ///
  /// Not an error, and not silent either. A capture whose device segment this
  /// package has no mapping for would otherwise vanish between the generator
  /// and the store without anything saying so.
  final List<String> unmappedScreenshots;

  /// Locales asked for and not found, or holding nothing to publish.
  final List<String> skippedLocales;

  /// Locales that failed partway, and why.
  ///
  /// A publish continues past a failing locale rather than aborting: with no
  /// transaction to roll back, stopping early only means fewer locales are
  /// updated, not that the store is left consistent.
  final Map<String, String> failedLocales;

  /// Total screenshots uploaded across every locale and slot.
  int get screenshotCount => uploadedScreenshots.values
      .expand((slots) => slots.values)
      .fold(0, (sum, count) => sum + count);

  /// Total screenshots deleted across every locale and slot.
  int get deletedCount => deletedScreenshots.values
      .expand((slots) => slots.values)
      .fold(0, (sum, count) => sum + count);

  /// Whether nothing at all was written.
  bool get isEmpty =>
      appInfoLocales.isEmpty &&
      versionLocales.isEmpty &&
      screenshotCount == 0;

  /// Whether any locale failed partway.
  bool get hasFailures => failedLocales.isNotEmpty;

  @override
  String toString() {
    final parts = <String>[
      '${appInfoLocales.length} app info',
      '${versionLocales.length} version text',
      '$screenshotCount screenshots',
      if (deletedCount > 0) '$deletedCount deleted',
      if (unmappedScreenshots.isNotEmpty)
        '${unmappedScreenshots.length} unmapped',
      if (skippedLocales.isNotEmpty) '${skippedLocales.length} skipped',
      if (failedLocales.isNotEmpty) '${failedLocales.length} failed',
    ];
    return 'AppStorePublishReport(${parts.join(', ')})';
  }
}
