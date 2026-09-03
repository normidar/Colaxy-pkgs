import 'dart:io';

import 'package:characters/characters.dart';
import 'package:colaxy_store_publish/src/core/store_publish_exception.dart';
import 'package:colaxy_store_publish/src/fastlane/fastlane_listing.dart';
import 'package:colaxy_store_publish/src/fastlane/fastlane_metadata.dart';
import 'package:colaxy_store_publish/src/fastlane/metadata_issue.dart';
import 'package:colaxy_store_publish/src/google_play/play_image_type.dart';
import 'package:colaxy_store_publish/src/publish/play_publish_options.dart';
import 'package:path/path.dart' as p;

/// Checks a local metadata tree before anything is sent to Google Play.
///
/// This is the one thing `fastlane supply` could not do for this repository,
/// and it exists only because the generators and the publisher are now in the
/// same language: `colaxy_localization` writes files, `colaxy_store_publish`
/// reads them, and nothing in between ever compared the two.
///
/// **What it checks is deliberately narrow.** Two kinds of thing:
///
/// 1. **Silent mistakes.** [FastlaneMetadata] skips what it does not
///    recognise, because a metadata tree also holds iOS material — so a
///    directory named `phonescreenshots` uploads nothing, reports success,
///    and looks identical to a run that worked. These checks are the only
///    place that ever becomes visible.
/// 2. **Google's documented text limits**, as warnings. The store enforces
///    them; repeating them here saves a round trip and never vetoes.
///
/// What it does **not** check is anything Google decides: image dimensions,
/// aspect ratios, how many screenshots a listing needs, whether a locale is
/// enabled for the app. A second, staler rulebook would reject combinations
/// the store accepts.
///
/// ## Parameters
///
/// ### Required
/// - **[metadata]**: The tree to check.
///
/// ### Optional
/// - **[options]**: The options the publish will run with, so the check sees
///   the same locales and flags (default: `PlayPublishOptions()`).
///
/// ## Example
///
/// ```dart
/// final issues = MetadataCheck(metadata: metadata).run();
/// if (issues.any((issue) => issue.severity.blocks)) return;
/// ```
class MetadataCheck {
  /// Creates a check over one metadata tree.
  const MetadataCheck({
    required this.metadata,
    this.options = const PlayPublishOptions(),
  });

  /// Longest title Google Play accepts, in user-perceived characters.
  static const maxTitleLength = 30;

  /// Longest short description Google Play accepts.
  static const maxShortDescriptionLength = 80;

  /// Longest full description Google Play accepts.
  static const maxFullDescriptionLength = 4000;

  /// Text files a locale directory may hold, for Google Play.
  ///
  /// Anything else ending in `.txt` is reported, because the App Store's file
  /// names — `description.txt`, `name.txt`, `keywords.txt` — are similar
  /// enough to land here by mistake and are then silently ignored.
  static const _knownTextFiles = {
    'title.txt',
    'short_description.txt',
    'full_description.txt',
    'video.txt',
  };

  /// The tree to check.
  final FastlaneMetadata metadata;

  /// The options the publish will run with.
  final PlayPublishOptions options;

  /// Every issue found, errors first.
  ///
  /// Makes no network calls, so it is safe to run in a pre-commit hook or
  /// ahead of a build.
  ///
  /// ## Example
  ///
  /// ```dart
  /// for (final issue in MetadataCheck(metadata: metadata).run()) {
  ///   stderr.writeln(issue);
  /// }
  /// ```
  List<MetadataIssue> run() {
    final issues = <MetadataIssue>[];

    final List<String> available;
    try {
      available = metadata.locales();
    } on FastlaneLayoutException catch (error) {
      return [
        MetadataIssue.error(
          error.message,
          path: error.path,
          fix: 'run colaxy_localization, or pass the right project root',
        ),
      ];
    }

    if (available.isEmpty) {
      issues.add(
        MetadataIssue.error(
          'The metadata directory holds no locale directories.',
          path: metadata.directory.path,
          fix: 'generate metadata before publishing',
        ),
      );
    }

    for (final locale in options.locales ?? const <String>[]) {
      if (available.contains(locale)) continue;
      issues.add(
        MetadataIssue.error(
          'Asked to publish this locale, but it has no directory.',
          locale: locale,
          path: p.join(metadata.directory.path, locale),
          fix: 'generate it, or drop it from the locale list',
        ),
      );
    }

    issues
      ..addAll([
        for (final locale in available)
          if (options.includes(locale)) ..._checkLocale(locale),
      ])
      ..addAll(_checkStrayFeatureGraphic(available))
      ..sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return issues;
  }

  List<MetadataIssue> _checkLocale(String locale) {
    final issues = <MetadataIssue>[
      ..._checkText(locale),
      ..._checkLooseFiles(locale),
      ..._checkImages(locale),
      ..._checkChangelogs(locale),
    ];

    final listing = metadata.listing(locale);
    if (listing.isEmpty && metadata.imageSets(locale).isEmpty) {
      issues.add(
        MetadataIssue.warning(
          'Nothing to publish for this locale; it will be skipped.',
          locale: locale,
          path: p.join(metadata.directory.path, locale),
        ),
      );
    }
    return issues;
  }

  /// Google's documented length limits, counted the way the store counts.
  ///
  /// Grapheme clusters, not UTF-16 code units: an emoji or a combining
  /// sequence inflates `String.length` and would report a valid title as too
  /// long. `colaxy_localization` learned this the same way.
  List<MetadataIssue> _checkText(String locale) {
    final listing = metadata.listing(locale);
    final limits = <String, (String?, int)>{
      'title.txt': (listing.title, maxTitleLength),
      'short_description.txt': (
        listing.shortDescription,
        maxShortDescriptionLength,
      ),
      'full_description.txt': (
        listing.fullDescription,
        maxFullDescriptionLength,
      ),
    };

    final issues = <MetadataIssue>[];
    for (final entry in limits.entries) {
      final (text, limit) = entry.value;
      if (text == null) continue;
      final length = text.characters.length;
      if (length <= limit) continue;
      issues.add(
        MetadataIssue.warning(
          'Google Play allows $limit characters here; this is $length.',
          locale: locale,
          path: p.join(metadata.directory.path, locale, entry.key),
          fix: 'shorten it, or let Google reject the publish',
        ),
      );
    }
    return issues;
  }

  /// Text files in a locale directory that this package will not read.
  List<MetadataIssue> _checkLooseFiles(String locale) {
    final directory = Directory(p.join(metadata.directory.path, locale));
    if (!directory.existsSync()) return const [];

    final issues = <MetadataIssue>[];
    for (final entry in directory.listSync()) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);
      if (p.extension(name).toLowerCase() != '.txt') continue;
      if (_knownTextFiles.contains(name)) continue;
      issues.add(
        MetadataIssue.warning(
          'Not a Google Play metadata file; it is ignored.',
          locale: locale,
          path: entry.path,
          fix: 'App Store files belong under fastlane/metadata/<locale>/',
        ),
      );
    }
    return issues;
  }

  /// Slot directories that do not name a slot, and files that cannot upload.
  ///
  /// The typo case is the whole reason this class exists: `phonescreenshots`
  /// is skipped in silence, so a run that uploads nothing looks exactly like
  /// a run that worked.
  List<MetadataIssue> _checkImages(String locale) {
    final imagesDirectory = Directory(
      p.join(metadata.directory.path, locale, 'images'),
    );
    if (!imagesDirectory.existsSync()) return const [];

    final issues = <MetadataIssue>[];
    for (final entry in imagesDirectory.listSync()) {
      final name = p.basename(entry.path);
      if (entry is Directory) {
        final type = PlayImageType.byDirectoryName(name);
        if (type == null) {
          issues.add(
            MetadataIssue.warning(
              'Not a Google Play image slot; every file under it is ignored.',
              locale: locale,
              path: entry.path,
              fix: _suggestSlot(name),
            ),
          );
          continue;
        }
        issues.addAll(_checkSlotFiles(locale, entry, type));
      } else if (entry is File) {
        final stem = p.basenameWithoutExtension(name);
        if (!_isImage(entry.path)) {
          issues.add(
            MetadataIssue.warning(
              'Not an image this package uploads; it is ignored.',
              locale: locale,
              path: entry.path,
            ),
          );
        } else if (PlayImageType.byDirectoryName(stem) == null) {
          issues.add(
            MetadataIssue.warning(
              'Not a Google Play image slot; this file is ignored.',
              locale: locale,
              path: entry.path,
              fix: _suggestSlot(stem),
            ),
          );
        }
      }
    }
    return issues;
  }

  List<MetadataIssue> _checkSlotFiles(
    String locale,
    Directory directory,
    PlayImageType type,
  ) {
    final issues = <MetadataIssue>[];
    var images = 0;
    for (final entry in directory.listSync()) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);
      if (name.startsWith('.')) continue;
      if (_isImage(entry.path)) {
        images++;
      } else {
        issues.add(
          MetadataIssue.warning(
            'Google Play takes PNG and JPEG; this file is ignored.',
            locale: locale,
            path: entry.path,
          ),
        );
      }
    }
    if (images == 0) {
      issues.add(
        MetadataIssue.warning(
          '${type.wireName} holds no images; nothing will be uploaded to it.',
          locale: locale,
          path: directory.path,
        ),
      );
    }
    return issues;
  }

  /// Changelog files that will never be selected.
  List<MetadataIssue> _checkChangelogs(String locale) {
    final listing = metadata.listing(locale);
    if (listing.changelogs.isEmpty) return const [];
    if (listing.changelogs.containsKey(FastlaneListing.defaultChangelogKey)) {
      return const [];
    }
    final names = listing.changelogs.keys.toList()..sort();
    if (names.every((name) => int.tryParse(name) != null)) return const [];
    return [
      MetadataIssue.warning(
        'Changelog files named after neither a version code nor "default": '
        '${names.where((name) => int.tryParse(name) == null).join(', ')}. '
        'They will never be selected.',
        locale: locale,
        path: p.join(metadata.directory.path, locale, 'changelogs'),
        fix: 'rename to default.txt or <versionCode>.txt',
      ),
    ];
  }

  /// The locale-independent feature graphic, when it will go nowhere.
  List<MetadataIssue> _checkStrayFeatureGraphic(List<String> available) {
    final stray = metadata.strayFeatureGraphic;
    if (stray == null || options.uploadStrayFeatureGraphic) return const [];

    final covered = available.where(
      (locale) => metadata
          .imageSets(locale)
          .any((set) => set.imageType == PlayImageType.featureGraphic),
    );
    if (covered.length == available.length) return const [];

    return [
      MetadataIssue.warning(
        'A feature graphic sits outside the fastlane layout and will not be '
        'uploaded. colaxy_screenshot writes it here; supply never read it '
        'either.',
        path: stray.path,
        fix: 'set uploadStrayFeatureGraphic, or move it to '
            '<locale>/images/featureGraphic.png',
      ),
    ];
  }

  /// The slot [name] was probably meant to be, when it is close to one.
  ///
  /// Case is the common miss, because the directory names are camelCase and
  /// nothing else in a metadata tree is.
  static String? _suggestSlot(String name) {
    final lowered = name.toLowerCase();
    for (final type in PlayImageType.values) {
      if (type.wireName.toLowerCase() == lowered) {
        return 'rename to ${type.wireName}';
      }
    }
    return null;
  }

  static bool _isImage(String path) => const {
    '.png',
    '.jpg',
    '.jpeg',
  }.contains(p.extension(path).toLowerCase());
}
