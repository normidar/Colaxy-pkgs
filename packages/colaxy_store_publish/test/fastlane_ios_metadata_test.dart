import 'dart:io';

import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

/// Builds `<temp>/fastlane/metadata/<locale>/…` and
/// `<temp>/fastlane/screenshots/<locale>/…`.
Directory _buildTree({
  Map<String, Map<String, String>> metadata = const {},
  Map<String, List<String>> screenshots = const {},
  bool withAndroid = true,
}) {
  final temp = Directory.systemTemp.createTempSync('colaxy_ios_meta');
  final root = p.join(temp.path, 'fastlane');

  if (withAndroid) {
    Directory(p.join(root, 'metadata', 'android', 'ja-JP'))
        .createSync(recursive: true);
  }
  for (final locale in metadata.entries) {
    for (final file in locale.value.entries) {
      File(p.join(root, 'metadata', locale.key, file.key))
        ..createSync(recursive: true)
        ..writeAsStringSync(file.value);
    }
  }
  for (final locale in screenshots.entries) {
    for (final name in locale.value) {
      File(p.join(root, 'screenshots', locale.key, name))
        ..createSync(recursive: true)
        ..writeAsBytesSync(onePixelPng);
    }
  }
  return temp;
}

FastlaneIosMetadata _read(Directory temp) =>
    FastlaneIosMetadata.forProject(temp.path);

void main() {
  late Directory temp;

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('locales', () {
    test('excludes the android directory, which sits at the same level', () {
      // metadata/android/ holds the Google Play tree and is not a locale, but
      // it is a sibling of ja and en-US.
      temp = _buildTree(
        metadata: {
          'ja': {'name.txt': 'メモ'},
          'en-US': {'name.txt': 'Notes'},
        },
      );

      expect(_read(temp).locales(), ['en-US', 'ja']);
    });

    test('names the missing directory rather than answering empty', () {
      temp = _buildTree();
      final missing = FastlaneIosMetadata(
        metadataDirectory: Directory(p.join(temp.path, 'nope')),
        screenshotsDirectory: Directory(p.join(temp.path, 'nope')),
      );

      expect(missing.locales, throwsA(isA<FastlaneLayoutException>()));
    });
  });

  group('listing', () {
    test('reads all nine files into the two halves', () {
      temp = _buildTree(
        metadata: {
          'ja': {
            'name.txt': 'メモ帳',
            'subtitle.txt': 'すぐ書ける',
            'privacy_url.txt': 'https://example.com/privacy',
            'description.txt': '長い説明',
            'keywords.txt': 'メモ,todo',
            'release_notes.txt': '不具合の修正',
            'promotional_text.txt': '宣伝',
            'support_url.txt': 'https://example.com/support',
            'marketing_url.txt': 'https://example.com',
          },
        },
      );

      final listing = _read(temp).listing('ja');

      expect(listing.name, 'メモ帳');
      expect(listing.privacyUrl, 'https://example.com/privacy');
      expect(listing.description, '長い説明');
      expect(listing.marketingUrl, 'https://example.com');
    });

    test('trims trailing newlines and reads blank files as absent', () {
      temp = _buildTree(
        metadata: {
          'ja': {'name.txt': 'メモ帳\n', 'subtitle.txt': '  \n'},
        },
      );

      final listing = _read(temp).listing('ja');

      expect(listing.name, 'メモ帳');
      expect(listing.subtitle, isNull);
    });

    test('an empty locale directory yields an empty listing', () {
      temp = _buildTree(metadata: {'ja': {}});
      Directory(p.join(temp.path, 'fastlane', 'metadata', 'ja'))
          .createSync(recursive: true);

      expect(_read(temp).listing('ja').isEmpty, isTrue);
    });
  });

  group('screenshots', () {
    test('groups by the device segment of the capture name', () {
      // colaxy_screenshot writes <index>_<device>_<page>.png.
      temp = _buildTree(
        screenshots: {
          'ja': [
            '1_iphone65_1.welcome.png',
            '2_iphone65_2.list.png',
            '1_ipadPro13_1.welcome.png',
          ],
        },
      );

      final grouped = _read(temp).screenshots('ja');

      expect(
        grouped[ScreenshotDisplayType.appIphone65],
        hasLength(2),
      );
      expect(
        grouped[ScreenshotDisplayType.appIpadPro3Gen129],
        hasLength(1),
      );
    });

    test('sorts within a slot, which is the only ordering the store keeps',
        () {
      temp = _buildTree(
        screenshots: {
          'ja': [
            '3_iphone65_3.png',
            '1_iphone65_1.png',
            '2_iphone65_2.png',
          ],
        },
      );

      final files = _read(temp).screenshots('ja')[
        ScreenshotDisplayType.appIphone65
      ]!;

      expect(
        files.map((f) => p.basename(f.path)),
        ['1_iphone65_1.png', '2_iphone65_2.png', '3_iphone65_3.png'],
      );
    });

    test('reports files it cannot place instead of dropping them', () {
      // Silently skipping a screenshot is the failure this package exists to
      // avoid; on Android the check catches it, here the reader surfaces it.
      temp = _buildTree(
        screenshots: {
          'ja': [
            '1_iphone65_1.png',
            '1_pixelfold_1.png',
            'loose.png',
          ],
        },
      );

      final unmapped = _read(temp)
          .unmappedScreenshots('ja')
          .map((f) => p.basename(f.path));

      expect(unmapped, ['1_pixelfold_1.png', 'loose.png']);
      expect(_read(temp).screenshots('ja'), hasLength(1));
    });

    test('answers empty for a locale with no screenshot directory', () {
      temp = _buildTree(metadata: {'ja': {}});

      expect(_read(temp).screenshots('ja'), isEmpty);
      expect(_read(temp).unmappedScreenshots('ja'), isEmpty);
    });
  });

  group('display type mapping', () {
    test('maps every capture name colaxy_screenshot emits', () {
      // The three constants that package exposes: kIosPhoneDeviceName,
      // kIosTabletDeviceName, kMacDeviceName.
      for (final name in ['iphone65', 'ipadPro13', 'mac']) {
        expect(
          ScreenshotDisplayType.byCaptureName(name),
          isNotNull,
          reason: name,
        );
      }
    });

    test('answers null for an unknown device rather than guessing', () {
      // Guessing would put screenshots in the wrong device slot, which the
      // store accepts and a human then has to notice.
      expect(ScreenshotDisplayType.byCaptureName('iphone99'), isNull);
    });

    test('carries all 33 values from the specification', () {
      expect(ScreenshotDisplayType.values, hasLength(33));
      expect(
        ScreenshotDisplayType.byWireName('APP_IPHONE_67'),
        ScreenshotDisplayType.appIphone67,
      );
      expect(ScreenshotDisplayType.byWireName('APP_MADE_UP'), isNull);
    });

    test('separates iMessage slots from app slots', () {
      expect(ScreenshotDisplayType.imessageAppIphone67.isIMessage, isTrue);
      expect(ScreenshotDisplayType.appIphone67.isIMessage, isFalse);
    });
  });
}
