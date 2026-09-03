import 'dart:io';

import 'package:colaxy_store_publish/src/core/store_publish_exception.dart';
import 'package:colaxy_store_publish/src/fastlane/fastlane_image_set.dart';
import 'package:colaxy_store_publish/src/fastlane/fastlane_listing.dart';
import 'package:colaxy_store_publish/src/google_play/play_image_type.dart';
import 'package:path/path.dart' as p;

/// Reads the Android half of a fastlane metadata tree.
///
/// The layout is `fastlane supply`'s, which is also what `colaxy_localization`
/// and `colaxy_screenshot` already write:
///
/// ```text
/// fastlane/metadata/android/
/// ├── featureGraphic.png            ← see [strayFeatureGraphic]
/// └── ja-JP/
///     ├── title.txt
///     ├── short_description.txt
///     ├── full_description.txt
///     ├── video.txt
///     ├── changelogs/
///     │   ├── default.txt
///     │   └── 412.txt
///     └── images/
///         ├── featureGraphic.png
///         ├── icon.png
///         ├── phoneScreenshots/
///         ├── sevenInchScreenshots/
///         └── tenInchScreenshots/
/// ```
///
/// Keeping this convention as the interface, rather than inventing an
/// intermediate format, is what keeps the three packages independent: the
/// generators write files, this reads files, and neither has to know the
/// other exists.
///
/// Unknown files and directories are skipped rather than rejected. A metadata
/// tree also holds iOS material and whatever else a project put there, and
/// failing on the first unrecognised entry would make that unusable.
///
/// ## Parameters
///
/// ### Required
/// - **[directory]**: The `fastlane/metadata/android` directory itself.
///
/// ## Example
///
/// ```dart
/// final metadata = FastlaneMetadata.forProject('.');
/// for (final locale in metadata.locales()) {
///   print(metadata.listing(locale));
/// }
/// ```
class FastlaneMetadata {
  /// Creates a reader over an `android` metadata directory.
  FastlaneMetadata(this.directory);

  /// Creates a reader over `<rootPath>/fastlane/metadata/android`.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[rootPath]**: The project directory holding `fastlane/`.
  factory FastlaneMetadata.forProject(String rootPath) =>
      FastlaneMetadata(Directory(p.join(rootPath, 'fastlane', 'metadata',
          'android')));

  /// File names inside a locale directory, mapped to the listing field they
  /// fill.
  static const Map<String, _ListingField> _listingFiles = {
    'title.txt': _ListingField.title,
    'short_description.txt': _ListingField.shortDescription,
    'full_description.txt': _ListingField.fullDescription,
    'video.txt': _ListingField.video,
  };

  /// The `fastlane/metadata/android` directory.
  final Directory directory;

  /// Whether the metadata directory exists at all.
  bool get exists => directory.existsSync();

  /// A feature graphic sitting directly in the `android` directory.
  ///
  /// **Not part of the fastlane supply convention**, which puts it at
  /// `<locale>/images/featureGraphic.png`. `colaxy_screenshot` wrote it here
  /// before its 0.10.0 — as a single locale-independent file that `supply`
  /// never picked up either — so a tree generated before then has a feature
  /// graphic nothing has ever uploaded.
  ///
  /// It is surfaced rather than silently used because uploading one image to
  /// every locale is a decision, not a detail. `PlayPublishOptions` has a
  /// flag for it, off by default. Regenerating with a current
  /// `colaxy_screenshot` is the better fix.
  File? get strayFeatureGraphic {
    for (final extension in const ['.png', '.jpg', '.jpeg']) {
      final file = File(p.join(directory.path, 'featureGraphic$extension'));
      if (file.existsSync()) return file;
    }
    return null;
  }

  /// Every locale directory present, sorted.
  ///
  /// Any directory directly under `android/` is taken to be a locale, which
  /// is exactly the rule `supply` uses. Directories holding nothing this
  /// package can publish are still listed; [listing] answers an empty
  /// [FastlaneListing] for them.
  ///
  /// Throws [FastlaneLayoutException] if the metadata directory is missing,
  /// which is nearly always a wrong `rootPath` rather than a project with no
  /// metadata.
  List<String> locales() {
    if (!exists) {
      throw FastlaneLayoutException(
        'No fastlane Android metadata directory. Generate it with '
        'colaxy_localization, or point this at the directory that holds the '
        'locale folders.',
        path: directory.path,
      );
    }
    final names = <String>[
      for (final entry in directory.listSync())
        if (entry is Directory) p.basename(entry.path),
    ]..sort();
    return names;
  }

  /// The text files under [locale], read into one object.
  ///
  /// Every field is independently optional. A locale directory holding only
  /// `changelogs/` yields a listing whose text fields are all `null`, which
  /// publishes nothing and is not an error — that is what a project which
  /// only ships release notes looks like.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[locale]**: The directory name.
  FastlaneListing listing(String locale) {
    final localeDirectory = Directory(p.join(directory.path, locale));
    if (!localeDirectory.existsSync()) {
      throw FastlaneLayoutException(
        'No metadata directory for locale "$locale".',
        path: localeDirectory.path,
      );
    }

    String? title;
    String? shortDescription;
    String? fullDescription;
    String? video;
    for (final entry in _listingFiles.entries) {
      final text = _readText(File(p.join(localeDirectory.path, entry.key)));
      if (text == null) continue;
      switch (entry.value) {
        case _ListingField.title:
          title = text;
        case _ListingField.shortDescription:
          shortDescription = text;
        case _ListingField.fullDescription:
          fullDescription = text;
        case _ListingField.video:
          video = text;
      }
    }

    return FastlaneListing(
      locale: locale,
      title: title,
      shortDescription: shortDescription,
      fullDescription: fullDescription,
      video: video,
      changelogs: _changelogs(localeDirectory),
    );
  }

  /// The image sets under `<locale>/images/`, sorted by slot.
  ///
  /// Covers both shapes the convention uses: a directory per multi-image slot
  /// (`phoneScreenshots/`), and a single file per one-image slot
  /// (`icon.png`). Empty directories are dropped, so an image set in the
  /// result always has at least one file.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[locale]**: The directory name.
  List<FastlaneImageSet> imageSets(String locale) {
    final imagesDirectory = Directory(
      p.join(directory.path, locale, 'images'),
    );
    if (!imagesDirectory.existsSync()) return const [];

    final sets = <FastlaneImageSet>[];
    for (final entry in imagesDirectory.listSync()) {
      final name = p.basename(entry.path);
      if (entry is Directory) {
        final type = PlayImageType.byDirectoryName(name);
        if (type == null) continue;
        final files = _imagesIn(entry);
        if (files.isEmpty) continue;
        sets.add(
          FastlaneImageSet(locale: locale, imageType: type, files: files),
        );
      } else if (entry is File && _isImage(entry.path)) {
        final type = PlayImageType.byDirectoryName(
          p.basenameWithoutExtension(name),
        );
        if (type == null) continue;
        sets.add(
          FastlaneImageSet(locale: locale, imageType: type, files: [entry]),
        );
      }
    }
    sets.sort((a, b) => a.imageType.index.compareTo(b.imageType.index));
    return sets;
  }

  /// The `changelogs/` directory, keyed by file stem.
  Map<String, String> _changelogs(Directory localeDirectory) {
    final changelogDirectory = Directory(
      p.join(localeDirectory.path, 'changelogs'),
    );
    if (!changelogDirectory.existsSync()) return const {};

    final changelogs = <String, String>{};
    for (final entry in changelogDirectory.listSync()) {
      if (entry is! File || p.extension(entry.path) != '.txt') continue;
      final text = _readText(entry);
      if (text == null) continue;
      changelogs[p.basenameWithoutExtension(entry.path)] = text;
    }
    return changelogs;
  }

  /// The image files directly inside [directory], sorted by name.
  static List<File> _imagesIn(Directory directory) {
    final files = <File>[
      for (final entry in directory.listSync())
        if (entry is File && _isImage(entry.path)) entry,
    ]..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return files;
  }

  static bool _isImage(String path) =>
      const {'.png', '.jpg', '.jpeg'}.contains(p.extension(path)
          .toLowerCase());

  /// Reads [file], or answers `null` if it is absent or holds only spaces.
  ///
  /// The trailing newline a text editor adds would otherwise become part of
  /// a title, and a file emptied to blank a field reads as "leave it alone"
  /// rather than as an empty title — clearing a field is done by removing it
  /// in Play Console, not by shipping an empty file.
  static String? _readText(File file) {
    if (!file.existsSync()) return null;
    final text = file.readAsStringSync().trim();
    return text.isEmpty ? null : text;
  }
}

/// Which field of a listing a metadata file fills.
enum _ListingField { title, shortDescription, fullDescription, video }
