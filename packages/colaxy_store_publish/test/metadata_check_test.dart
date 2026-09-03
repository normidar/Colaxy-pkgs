import 'dart:io';

import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:test/test.dart';

import 'support.dart';

List<MetadataIssue> _run(
  Directory android, {
  PlayPublishOptions options = const PlayPublishOptions(),
}) => MetadataCheck(
  metadata: FastlaneMetadata(android),
  options: options,
).run();

Matcher _mentions(String fragment) => predicate<List<MetadataIssue>>(
  (issues) => issues.any((issue) => issue.toString().contains(fragment)),
  'an issue mentioning "$fragment"',
);

void main() {
  late Directory android;

  tearDown(() {
    final temp = android.parent.parent.parent;
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  group('silent mistakes', () {
    test('catches a misspelled slot directory and names the fix', () {
      // The whole reason this class exists: an unrecognised directory is
      // skipped by design, so a lowercase typo uploads nothing and reports
      // success.
      android = buildMetadataTree({
        'ja-JP': {
          'title.txt': 'メモ',
          'images/phonescreenshots/01.png': '',
        },
      });

      final issues = _run(android);

      expect(issues, _mentions('rename to phoneScreenshots'));
    });

    test('flags an unrecognised slot even with no near match', () {
      android = buildMetadataTree({
        'ja-JP': {
          'title.txt': 'メモ',
          'images/desktopShots/01.png': '',
        },
      });

      expect(_run(android), _mentions('desktopShots'));
    });

    test('flags an App Store file that landed in the android tree', () {
      // description.txt is the App Store's name for what Play calls
      // full_description.txt, and it is otherwise ignored in silence.
      android = buildMetadataTree({
        'ja-JP': {'description.txt': '長い説明'},
      });

      expect(_run(android), _mentions('description.txt'));
    });

    test('flags an image suffix Google Play will not take', () {
      android = buildMetadataTree({
        'ja-JP': {
          'title.txt': 'メモ',
          'images/phoneScreenshots/01.png': '',
        },
      });
      File('${android.path}/ja-JP/images/phoneScreenshots/02.webp')
          .writeAsBytesSync(onePixelPng);

      expect(_run(android), _mentions('PNG and JPEG'));
    });

    test('flags a slot directory holding no images', () {
      android = buildMetadataTree({
        'ja-JP': {
          'title.txt': 'メモ',
          'images/phoneScreenshots/.keep': '',
        },
      });

      expect(_run(android), _mentions('holds no images'));
    });

    test('flags changelogs that will never be selected', () {
      // Only default.txt and <versionCode>.txt are ever read.
      android = buildMetadataTree({
        'ja-JP': {'changelogs/release-notes.txt': '修正'},
      });

      expect(_run(android), _mentions('release-notes'));
    });

    test('accepts version-code changelogs with no default', () {
      android = buildMetadataTree({
        'ja-JP': {'title.txt': 'メモ', 'changelogs/412.txt': '修正'},
      });

      expect(_run(android), isNot(_mentions('never be selected')));
    });

    test('flags the stray feature graphic that will go nowhere', () {
      android = buildMetadataTree(
        {
          'ja-JP': {'title.txt': 'メモ'},
        },
        root: {'featureGraphic.png': ''},
      );

      expect(_run(android), _mentions('outside the fastlane layout'));
    });

    test('says nothing about the stray graphic once it is switched on', () {
      android = buildMetadataTree(
        {
          'ja-JP': {'title.txt': 'メモ'},
        },
        root: {'featureGraphic.png': ''},
      );

      expect(
        _run(
          android,
          options: const PlayPublishOptions(uploadStrayFeatureGraphic: true),
        ),
        isNot(_mentions('outside the fastlane layout')),
      );
    });

    test('says nothing when every locale has its own feature graphic', () {
      android = buildMetadataTree(
        {
          'ja-JP': {'images/featureGraphic.png': ''},
        },
        root: {'featureGraphic.png': ''},
      );

      expect(_run(android), isNot(_mentions('outside the fastlane layout')));
    });
  });

  group('text limits', () {
    test('reports an over-long title as a warning, not an error', () {
      android = buildMetadataTree({
        'ja-JP': {'title.txt': 'あ' * 31},
      });

      final issues = _run(android);

      expect(issues, _mentions('30 characters'));
      expect(
        issues.every((issue) => issue.severity == MetadataSeverity.warning),
        isTrue,
      );
    });

    test('counts grapheme clusters, not UTF-16 code units', () {
      // A title of 30 emoji is 60 code units. Counting those would reject a
      // title Google accepts — the same trap colaxy_localization documents.
      android = buildMetadataTree({
        'ja-JP': {'title.txt': '😀' * 30},
      });

      expect(_run(android), isNot(_mentions('characters here')));
    });

    test('catches a description pushed over the limit after generation', () {
      // colaxy_localization checks 4000 characters and *then* appends the
      // minimum-version footer, so a description at the limit exceeds it on
      // disk. The generator cannot catch this; the tree can.
      android = buildMetadataTree({
        'ja-JP': {
          'full_description.txt':
              '${'あ' * 4000}\n\n[Minimum supported app version: 1.2.0]',
        },
      });

      expect(_run(android), _mentions('4000 characters'));
    });

    test('accepts text exactly at the limit', () {
      android = buildMetadataTree({
        'ja-JP': {'short_description.txt': 'あ' * 80},
      });

      expect(_run(android), isEmpty);
    });
  });

  group('blocking problems', () {
    test('a missing metadata directory is an error, not a crash', () {
      android = buildMetadataTree({'ja-JP': {}});
      final missing = MetadataCheck(
        metadata: FastlaneMetadata(Directory('${android.path}/nope')),
      ).run();

      expect(missing.single.severity, MetadataSeverity.error);
    });

    test('a requested locale with no directory blocks', () {
      android = buildMetadataTree({
        'ja-JP': {'title.txt': 'メモ'},
      });

      final issues = _run(
        android,
        options: const PlayPublishOptions(locales: {'ja-JP', 'de-DE'}),
      );

      expect(issues.single.severity, MetadataSeverity.error);
      expect(issues.single.locale, 'de-DE');
    });

    test('a tree with no locale directories at all blocks', () {
      android = buildMetadataTree(const {});

      expect(_run(android).single.severity, MetadataSeverity.error);
    });

    test('errors sort ahead of warnings', () {
      android = buildMetadataTree({
        'ja-JP': {'title.txt': 'あ' * 31},
      });

      final issues = _run(
        android,
        options: const PlayPublishOptions(locales: {'ja-JP', 'de-DE'}),
      );

      expect(issues.first.severity, MetadataSeverity.error);
      expect(issues.last.severity, MetadataSeverity.warning);
    });
  });

  group('quiet on a healthy tree', () {
    test('finds nothing to say about a well-formed locale', () {
      android = buildMetadataTree({
        'ja-JP': {
          'title.txt': 'メモ帳',
          'short_description.txt': 'すぐ書ける',
          'full_description.txt': '長い説明',
          'changelogs/default.txt': '不具合の修正',
          'images/phoneScreenshots/01.png': '',
          'images/phoneScreenshots/02.png': '',
          'images/featureGraphic.png': '',
        },
      });

      expect(_run(android), isEmpty);
    });

    test('does not judge image dimensions', () {
      // One-pixel PNGs are not legal screenshots. Google says so, and this
      // check deliberately does not.
      android = buildMetadataTree({
        'ja-JP': {
          'title.txt': 'メモ',
          'images/phoneScreenshots/01.png': '',
        },
      });

      expect(_run(android), isEmpty);
    });

    test('skips locales the options exclude', () {
      android = buildMetadataTree({
        'ja-JP': {'title.txt': 'メモ'},
        'de-DE': {'title.txt': 'あ' * 31},
      });

      expect(
        _run(android, options: const PlayPublishOptions(locales: {'ja-JP'})),
        isEmpty,
      );
    });
  });
}
