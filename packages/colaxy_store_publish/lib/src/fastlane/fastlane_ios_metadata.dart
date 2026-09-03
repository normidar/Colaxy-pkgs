import 'dart:io';

import 'package:colaxy_store_publish/src/app_store/screenshot_display_type.dart';
import 'package:colaxy_store_publish/src/core/store_publish_exception.dart';
import 'package:colaxy_store_publish/src/fastlane/fastlane_ios_listing.dart';
import 'package:path/path.dart' as p;

/// Reads the App Store half of a fastlane tree.
///
/// Two directories, not one — and this is where the Android and Apple sides
/// stop looking alike on disk as well as over the wire:
///
/// ```text
/// fastlane/
/// ├── metadata/
/// │   ├── android/          ← FastlaneMetadata reads this
/// │   └── ja/               ← text, this class
/// │       ├── name.txt
/// │       ├── subtitle.txt
/// │       ├── description.txt
/// │       ├── keywords.txt
/// │       ├── release_notes.txt
/// │       ├── promotional_text.txt
/// │       ├── support_url.txt
/// │       └── privacy_url.txt
/// └── screenshots/
///     └── ja/               ← images, this class
///         ├── 1_iphone65_1.welcome.png
///         └── 1_ipadPro13_1.welcome.png
/// ```
///
/// The Android locale directories live *under* `metadata/android/`, so
/// `android` itself has to be skipped when listing App Store locales — it
/// sits at the same level as `ja` and `en-US`.
///
/// ## Parameters
///
/// ### Required
/// - **[metadataDirectory]**: `fastlane/metadata`.
/// - **[screenshotsDirectory]**: `fastlane/screenshots`.
///
/// ## Example
///
/// ```dart
/// final metadata = FastlaneIosMetadata.forProject('.');
/// for (final locale in metadata.locales()) {
///   print(metadata.listing(locale));
/// }
/// ```
class FastlaneIosMetadata {
  /// Creates a reader over the two directories.
  FastlaneIosMetadata({
    required this.metadataDirectory,
    required this.screenshotsDirectory,
  });

  /// Creates a reader over `<rootPath>/fastlane/`.
  factory FastlaneIosMetadata.forProject(String rootPath) =>
      FastlaneIosMetadata(
        metadataDirectory: Directory(p.join(rootPath, 'fastlane', 'metadata')),
        screenshotsDirectory: Directory(
          p.join(rootPath, 'fastlane', 'screenshots'),
        ),
      );

  /// The directory name under `metadata/` that is not an App Store locale.
  static const androidDirectoryName = 'android';

  /// File names mapped to the listing field they fill.
  static const Map<String, _IosField> _files = {
    'name.txt': _IosField.name,
    'subtitle.txt': _IosField.subtitle,
    'privacy_url.txt': _IosField.privacyUrl,
    'description.txt': _IosField.description,
    'keywords.txt': _IosField.keywords,
    'release_notes.txt': _IosField.releaseNotes,
    'promotional_text.txt': _IosField.promotionalText,
    'support_url.txt': _IosField.supportUrl,
    'marketing_url.txt': _IosField.marketingUrl,
  };

  /// `fastlane/metadata`.
  final Directory metadataDirectory;

  /// `fastlane/screenshots`.
  final Directory screenshotsDirectory;

  /// Whether the metadata directory exists at all.
  bool get exists => metadataDirectory.existsSync();

  /// Every App Store locale directory under `metadata/`, sorted.
  ///
  /// `android/` is excluded: it holds the Google Play tree and is not a
  /// locale, but it sits at exactly the same level as the locales.
  List<String> locales() {
    if (!exists) {
      throw FastlaneLayoutException(
        'No fastlane metadata directory. Generate it with '
        'colaxy_localization, or point this at the directory that holds the '
        'locale folders.',
        path: metadataDirectory.path,
      );
    }
    final names = <String>[
      for (final entry in metadataDirectory.listSync())
        if (entry is Directory &&
            p.basename(entry.path) != androidDirectoryName)
          p.basename(entry.path),
    ]..sort();
    return names;
  }

  /// The text files under [locale], read into one object.
  FastlaneIosListing listing(String locale) {
    final directory = Directory(p.join(metadataDirectory.path, locale));
    if (!directory.existsSync()) {
      throw FastlaneLayoutException(
        'No metadata directory for locale "$locale".',
        path: directory.path,
      );
    }

    final values = <_IosField, String>{};
    for (final entry in _files.entries) {
      final text = _readText(File(p.join(directory.path, entry.key)));
      if (text != null) values[entry.value] = text;
    }

    return FastlaneIosListing(
      locale: locale,
      name: values[_IosField.name],
      subtitle: values[_IosField.subtitle],
      privacyUrl: values[_IosField.privacyUrl],
      description: values[_IosField.description],
      keywords: values[_IosField.keywords],
      releaseNotes: values[_IosField.releaseNotes],
      promotionalText: values[_IosField.promotionalText],
      supportUrl: values[_IosField.supportUrl],
      marketingUrl: values[_IosField.marketingUrl],
    );
  }

  /// Screenshot files for [locale], grouped by the device slot they belong in.
  ///
  /// `colaxy_screenshot` names captures `<index>_<device>_<page>.png`, so the
  /// device is the second underscore-separated segment. Names that do not
  /// parse, or whose device this package has no mapping for, are **left out**
  /// — `unmappedScreenshots` reports them, because silently dropping a
  /// screenshot is the failure this whole package is built to avoid.
  ///
  /// Files within a slot are sorted by name, which is the only ordering the
  /// store honours.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[locale]**: The screenshot directory name.
  Map<ScreenshotDisplayType, List<File>> screenshots(String locale) {
    final grouped = <ScreenshotDisplayType, List<File>>{};
    for (final file in _screenshotFiles(locale)) {
      final type = _displayTypeOf(file);
      if (type == null) continue;
      (grouped[type] ??= <File>[]).add(file);
    }
    for (final files in grouped.values) {
      files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    }
    return grouped;
  }

  /// Screenshot files for [locale] this package cannot place, sorted.
  ///
  /// A file lands here when its name has no device segment, or names a device
  /// with no entry in [ScreenshotDisplayType.byCaptureName]. Both mean the
  /// screenshot would be skipped, and skipping in silence is what the
  /// Android-side check exists to prevent.
  List<File> unmappedScreenshots(String locale) {
    final unmapped = <File>[
      for (final file in _screenshotFiles(locale))
        if (_displayTypeOf(file) == null) file,
    ]..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return unmapped;
  }

  /// Every image directly under `screenshots/<locale>/`.
  List<File> _screenshotFiles(String locale) {
    final directory = Directory(p.join(screenshotsDirectory.path, locale));
    if (!directory.existsSync()) return const [];
    return [
      for (final entry in directory.listSync())
        if (entry is File && _isImage(entry.path)) entry,
    ];
  }

  /// The slot a capture file belongs in, from its `_<device>_` segment.
  static ScreenshotDisplayType? _displayTypeOf(File file) {
    final parts = p.basenameWithoutExtension(file.path).split('_');
    if (parts.length < 2) return null;
    return ScreenshotDisplayType.byCaptureName(parts[1]);
  }

  static bool _isImage(String path) => const {
    '.png',
    '.jpg',
    '.jpeg',
  }.contains(p.extension(path).toLowerCase());

  /// Reads [file], or answers `null` if it is absent or holds only spaces.
  static String? _readText(File file) {
    if (!file.existsSync()) return null;
    final text = file.readAsStringSync().trim();
    return text.isEmpty ? null : text;
  }
}

/// Which field of an App Store listing a metadata file fills.
enum _IosField {
  name,
  subtitle,
  privacyUrl,
  description,
  keywords,
  releaseNotes,
  promotionalText,
  supportUrl,
  marketingUrl,
}
