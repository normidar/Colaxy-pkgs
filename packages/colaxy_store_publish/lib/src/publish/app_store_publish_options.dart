import 'package:meta/meta.dart';

/// What an App Store publish should and should not do.
///
/// The defaults err the same way as the Google Play ones — **nothing is
/// deleted unless asked** — but the reasoning differs in one place.
/// `appScreenshotSets` has no `PATCH`, so replacing a set means deleting its
/// members one at a time. There is no atomic swap to offer.
///
/// ## Parameters
///
/// ### Optional
/// - **[locales]**: Which locale directories to publish (default: `null`,
///   meaning every one found).
/// - **[publishAppInfo]**: Whether to write the app-wide half — name,
///   subtitle, privacy policy URL (default: `true`).
/// - **[publishVersionText]**: Whether to write the version-scoped half —
///   description, keywords, release notes (default: `true`).
/// - **[publishScreenshots]**: Whether to upload screenshots
///   (default: `true`).
/// - **[replaceScreenshots]**: Whether to empty each set before uploading
///   into it (default: `false`).
/// - **[awaitProcessing]**: Whether to wait for Apple to finish processing
///   each screenshot (default: `true`).
/// - **[platform]**: Narrow the version lookup to one platform
///   (default: `null`).
///
/// ## Example
///
/// ```dart
/// // Release notes only, for a version already on the store.
/// const options = AppStorePublishOptions(
///   publishAppInfo: false,
///   publishScreenshots: false,
/// );
/// ```
@immutable
class AppStorePublishOptions {
  /// Creates publish options.
  const AppStorePublishOptions({
    this.locales,
    this.publishAppInfo = true,
    this.publishVersionText = true,
    this.publishScreenshots = true,
    this.replaceScreenshots = false,
    this.awaitProcessing = true,
    this.platform,
  });

  /// Which locale directories to publish, or `null` for all of them.
  final Set<String>? locales;

  /// Whether to write the app-wide half of the metadata.
  ///
  /// Separate from [publishVersionText] because the two go to different
  /// resources through different records, and one can be writable while the
  /// other is not.
  final bool publishAppInfo;

  /// Whether to write the version-scoped half of the metadata.
  final bool publishVersionText;

  /// Whether to upload screenshots.
  final bool publishScreenshots;

  /// Whether to empty each screenshot set before uploading into it.
  ///
  /// Destructive, and slower than it looks: Apple has no bulk delete, so this
  /// is one request per existing screenshot.
  final bool replaceScreenshots;

  /// Whether to wait for Apple to finish processing each screenshot.
  ///
  /// On by default, unlike the destructive switches. Processing is
  /// asynchronous and can reject an asset that uploaded cleanly; a run that
  /// does not wait reports success and the failure surfaces later as
  /// "there are still screenshot uploads in progress" at submission time,
  /// naming neither the file nor the reason.
  final bool awaitProcessing;

  /// Narrow the version lookup to one platform, e.g. `IOS`.
  final String? platform;

  /// Whether [locale] should be published under these options.
  bool includes(String locale) => locales?.contains(locale) ?? true;
}
