import 'dart:io';

import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late Directory android;

  tearDown(() {
    // buildMetadataTree returns <temp>/fastlane/metadata/android.
    final temp = android.parent.parent.parent;
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  group('locales', () {
    test('lists locale directories, sorted, ignoring loose files', () {
      android = buildMetadataTree(
        {
          'ja-JP': {'title.txt': 'メモ'},
          'en-US': {'title.txt': 'Notes'},
        },
        root: {'featureGraphic.png': ''},
      );

      expect(FastlaneMetadata(android).locales(), ['en-US', 'ja-JP']);
    });

    test('names the missing directory rather than answering empty', () {
      android = buildMetadataTree({'ja-JP': {}});
      final missing = FastlaneMetadata(
        Directory(p.join(android.path, 'nope')),
      );

      expect(
        missing.locales,
        throwsA(
          isA<FastlaneLayoutException>().having(
            (error) => error.path,
            'path',
            contains('nope'),
          ),
        ),
      );
    });
  });

  group('listing', () {
    test('maps each file onto its listing field', () {
      android = buildMetadataTree({
        'ja-JP': {
          'title.txt': 'メモ帳',
          'short_description.txt': 'すぐ書ける',
          'full_description.txt': '長い説明',
          'video.txt': 'https://youtu.be/abc',
        },
      });

      final listing = FastlaneMetadata(android).listing('ja-JP');

      expect(listing.title, 'メモ帳');
      expect(listing.shortDescription, 'すぐ書ける');
      expect(listing.fullDescription, '長い説明');
      expect(listing.video, 'https://youtu.be/abc');
    });

    test('trims the trailing newline an editor leaves behind', () {
      android = buildMetadataTree({
        'ja-JP': {'title.txt': 'メモ帳\n'},
      });

      expect(FastlaneMetadata(android).listing('ja-JP').title, 'メモ帳');
    });

    test('reads a blank file as absent, not as an empty title', () {
      // Shipping an empty title would clear the store's title. A file
      // emptied by hand means "I have nothing here", not "delete it".
      android = buildMetadataTree({
        'ja-JP': {'title.txt': '   \n'},
      });

      expect(FastlaneMetadata(android).listing('ja-JP').title, isNull);
    });

    test('leaves fields with no file null', () {
      android = buildMetadataTree({
        'ja-JP': {'title.txt': 'メモ帳'},
      });

      final listing = FastlaneMetadata(android).listing('ja-JP');

      expect(listing.fullDescription, isNull);
      expect(listing.shortDescription, isNull);
      expect(listing.isEmpty, isFalse);
    });

    test('collects changelogs by file stem', () {
      android = buildMetadataTree({
        'ja-JP': {
          'changelogs/default.txt': '不具合の修正',
          'changelogs/412.txt': '新機能',
        },
      });

      final listing = FastlaneMetadata(android).listing('ja-JP');

      expect(listing.changelogFor(412), '新機能');
      expect(listing.changelogFor(999), '不具合の修正');
      expect(listing.changelogFor(null), '不具合の修正');
    });

    test('changelogs alone leave the listing text empty', () {
      android = buildMetadataTree({
        'ja-JP': {'changelogs/default.txt': '不具合の修正'},
      });

      final listing = FastlaneMetadata(android).listing('ja-JP');

      expect(listing.isEmpty, isFalse);
      expect(listing.toPlayListing().isEmpty, isTrue);
    });
  });

  group('imageSets', () {
    test('turns directory names into slots without a lookup table', () {
      android = buildMetadataTree({
        'ja-JP': {
          'images/phoneScreenshots/01.png': '',
          'images/phoneScreenshots/02.png': '',
          'images/tenInchScreenshots/01.png': '',
        },
      });

      final sets = FastlaneMetadata(android).imageSets('ja-JP');

      expect(
        sets.map((set) => set.imageType),
        [PlayImageType.phoneScreenshots, PlayImageType.tenInchScreenshots],
      );
      expect(sets.first.files, hasLength(2));
    });

    test('sorts files by name, which is the only ordering Play honours', () {
      android = buildMetadataTree({
        'ja-JP': {
          'images/phoneScreenshots/03.png': '',
          'images/phoneScreenshots/01.png': '',
          'images/phoneScreenshots/02.png': '',
        },
      });

      final files = FastlaneMetadata(android)
          .imageSets('ja-JP')
          .single
          .files
          .map((file) => p.basename(file.path));

      expect(files, ['01.png', '02.png', '03.png']);
    });

    test('reads single-image slots from files, not directories', () {
      android = buildMetadataTree({
        'ja-JP': {
          'images/featureGraphic.png': '',
          'images/icon.png': '',
        },
      });

      final sets = FastlaneMetadata(android).imageSets('ja-JP');

      expect(
        sets.map((set) => set.imageType).toSet(),
        {PlayImageType.icon, PlayImageType.featureGraphic},
      );
    });

    test('skips unknown directories instead of failing the run', () {
      android = buildMetadataTree({
        'ja-JP': {
          'images/phoneScreenshots/01.png': '',
          'images/notASlot/01.png': '',
          'images/readme.md': 'notes',
        },
      });

      expect(FastlaneMetadata(android).imageSets('ja-JP'), hasLength(1));
    });

    test('drops empty slot directories', () {
      android = buildMetadataTree({
        'ja-JP': {'images/phoneScreenshots/.keep': ''},
      });

      expect(FastlaneMetadata(android).imageSets('ja-JP'), isEmpty);
    });
  });

  group('strayFeatureGraphic', () {
    test('finds the locale-independent file colaxy_screenshot writes', () {
      android = buildMetadataTree(
        {'ja-JP': {}},
        root: {'featureGraphic.png': ''},
      );

      expect(FastlaneMetadata(android).strayFeatureGraphic, isNotNull);
    });

    test('is null when the convention was followed', () {
      android = buildMetadataTree({
        'ja-JP': {'images/featureGraphic.png': ''},
      });

      expect(FastlaneMetadata(android).strayFeatureGraphic, isNull);
    });
  });
}
