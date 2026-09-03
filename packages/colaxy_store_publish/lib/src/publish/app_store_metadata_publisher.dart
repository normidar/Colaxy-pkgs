import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/app_store_publisher.dart';
import 'package:colaxy_store_publish/src/app_store/screenshot_display_type.dart';
import 'package:colaxy_store_publish/src/core/store_publish_exception.dart';
import 'package:colaxy_store_publish/src/fastlane/fastlane_ios_metadata.dart';
import 'package:colaxy_store_publish/src/publish/app_store_publish_options.dart';
import 'package:colaxy_store_publish/src/publish/app_store_publish_report.dart';

/// Writes a fastlane tree to the App Store.
///
/// The Apple counterpart of `PlayMetadataPublisher`, and deliberately **not**
/// the same shape. That one stages changes into an edit and hands the commit
/// back to the caller; this one has nothing to stage into, so every write is
/// live the moment it is made.
///
/// Two consequences follow, and both are visible in the API here:
///
/// - **There is no `dryRun`.** Google Play has `edits.validate`; App Store
///   Connect has no equivalent, and a locally-invented imitation would check
///   different things than the store does. Use `publishAppInfo: false` and
///   friends to narrow what a run touches instead.
/// - **A failing locale does not abort the run.** With no rollback, stopping
///   early leaves the store just as half-updated as continuing does, minus
///   the locales that would have worked. Failures are collected into
///   `AppStorePublishReport.failedLocales`.
///
/// ## Parameters
///
/// ### Required
/// - **[publisher]**: An authenticated App Store publisher.
/// - **[metadata]**: The fastlane tree to read.
///
/// ### Optional
/// - **[options]**: What to write and what to leave alone (default:
///   `AppStorePublishOptions()`).
/// - **[onLog]**: Receives one line per locale and slot (default: `null`).
///
/// ## Example
///
/// ```dart
/// final report = await AppStoreMetadataPublisher(
///   publisher: publisher,
///   metadata: FastlaneIosMetadata.forProject('.'),
/// ).publish();
/// if (report.hasFailures) stderr.writeln(report.failedLocales);
/// ```
class AppStoreMetadataPublisher {
  /// Creates a publisher over one fastlane tree.
  AppStoreMetadataPublisher({
    required this.publisher,
    required this.metadata,
    this.options = const AppStorePublishOptions(),
    this.onLog,
  });

  /// An authenticated App Store publisher.
  final AppStorePublisher publisher;

  /// The fastlane tree to read.
  final FastlaneIosMetadata metadata;

  /// What to write and what to leave alone.
  final AppStorePublishOptions options;

  /// Receives one line per locale and slot.
  final StoreConsoleLog? onLog;

  /// Writes every selected locale to the store.
  ///
  /// Finds the editable version and app info record first. If neither is
  /// editable there is nothing to write to, and the run reports that rather
  /// than writing somewhere invisible — which is what picking the first
  /// record would do.
  Future<AppStorePublishReport> publish() async {
    final version = options.publishVersionText || options.publishScreenshots
        ? await publisher.versions.editable(platform: options.platform)
        : null;
    if ((options.publishVersionText || options.publishScreenshots) &&
        version == null) {
      throw const FastlaneLayoutException(
        'No App Store version is in PREPARE_FOR_SUBMISSION, so there is '
        'nothing to write version metadata or screenshots to. Create the '
        'next version in App Store Connect first — doing that automatically '
        'is a release decision, not a publishing detail.',
      );
    }

    final appInfo = options.publishAppInfo
        ? await publisher.appInfos.editable()
        : null;
    if (options.publishAppInfo && appInfo == null) {
      throw const FastlaneLayoutException(
        'No editable app info record. App-wide metadata (name, subtitle, '
        'privacy policy) cannot be written right now. Writing through a '
        'record in another state succeeds and changes nothing, so this run '
        'stops instead.',
      );
    }

    final available = metadata.locales().toSet();
    final requested = options.locales;
    final selected = <String>[
      for (final locale in requested ?? available)
        if (available.contains(locale) && options.includes(locale)) locale,
    ]..sort();
    final skipped = <String>[
      for (final locale in requested ?? const <String>[])
        if (!available.contains(locale)) locale,
    ];

    final appInfoLocales = <String>[];
    final versionLocales = <String>[];
    final uploaded = <String, Map<ScreenshotDisplayType, int>>{};
    final deleted = <String, Map<ScreenshotDisplayType, int>>{};
    final unmapped = <String>[];
    final failed = <String, String>{};

    final versionApi = version == null
        ? null
        : publisher.versionLocalizations(version);
    final appInfoApi = appInfo == null
        ? null
        : publisher.appInfoLocalizations(appInfo);

    for (final locale in selected) {
      final listing = metadata.listing(locale);
      var touched = false;

      try {
        if (appInfoApi != null && !listing.appInfoLocalization().isEmpty) {
          await appInfoApi.update(listing.appInfoLocalization());
          appInfoLocales.add(locale);
          touched = true;
          onLog?.call('wrote app info for $locale');
        }

        if (options.publishVersionText &&
            versionApi != null &&
            !listing.versionLocalization().isEmpty) {
          await versionApi.update(listing.versionLocalization());
          versionLocales.add(locale);
          touched = true;
          onLog?.call('wrote version text for $locale');
        }

        if (options.publishScreenshots && versionApi != null) {
          unmapped.addAll(
            metadata.unmappedScreenshots(locale).map((file) => file.path),
          );
          final counts = await _publishScreenshots(
            locale: locale,
            localizationId: (await versionApi.get(locale))?.id,
            deleted: deleted,
          );
          if (counts.isNotEmpty) {
            uploaded[locale] = counts;
            touched = true;
          }
        }
      } on StoreConsoleException catch (error) {
        // No transaction to roll back, so continuing costs nothing that
        // stopping would save.
        failed[locale] = error.toString();
        onLog?.call('failed on $locale: $error');
        continue;
      }

      if (!touched) skipped.add(locale);
    }

    skipped.sort();
    unmapped.sort();
    return AppStorePublishReport(
      appInfoLocales: appInfoLocales,
      versionLocales: versionLocales,
      uploadedScreenshots: uploaded,
      deletedScreenshots: deleted,
      unmappedScreenshots: unmapped,
      skippedLocales: skipped,
      failedLocales: failed,
    );
  }

  /// Uploads every screenshot for [locale], recording deletions in [deleted].
  Future<Map<ScreenshotDisplayType, int>> _publishScreenshots({
    required String locale,
    required String? localizationId,
    required Map<String, Map<ScreenshotDisplayType, int>> deleted,
  }) async {
    final grouped = metadata.screenshots(locale);
    if (grouped.isEmpty) return const {};
    if (localizationId == null) {
      // Screenshots hang off a version localization, so there is nowhere to
      // put them until that exists.
      onLog?.call(
        'no version localization for $locale; screenshots skipped',
      );
      return const {};
    }

    final counts = <ScreenshotDisplayType, int>{};
    for (final entry in grouped.entries) {
      final set = await publisher.screenshots.ensureSet(
        localizationId: localizationId,
        displayType: entry.key,
      );

      if (options.replaceScreenshots) {
        final removed = await publisher.screenshots.deleteAll(set.id);
        if (removed > 0) {
          (deleted[locale] ??= {})[entry.key] = removed;
        }
      }

      for (final file in entry.value) {
        await _uploadOne(set.id, file);
      }
      counts[entry.key] = entry.value.length;
      onLog?.call(
        'uploaded ${entry.value.length} to $locale/${entry.key.wireName}',
      );
    }
    return counts;
  }

  Future<void> _uploadOne(String setId, File file) async {
    final screenshot = await publisher.screenshots.upload(
      setId: setId,
      file: file,
    );
    if (!options.awaitProcessing) return;
    // Processing is asynchronous and can reject an asset that uploaded
    // cleanly. Waiting here turns that into a failure naming the file.
    await publisher.screenshots.awaitProcessing(screenshot.id);
  }
}
