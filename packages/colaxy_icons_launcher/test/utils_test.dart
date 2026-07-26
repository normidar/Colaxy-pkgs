import 'package:colaxy_icons_launcher/utils/utils.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('platform config checks', () {
    test('hasPlatformConfig is false without a platforms key', () {
      expect(hasPlatformConfig({'image_path': 'icon.png'}), isFalse);
    });

    test('hasPlatformConfig is false when no platform is enabled', () {
      expect(
        hasPlatformConfig({
          'platforms': {
            'android': {'enable': false},
            'ios': {'enable': false},
          },
        }),
        isFalse,
      );
    });

    test('hasPlatformConfig is true when any platform is enabled', () {
      expect(
        hasPlatformConfig({
          'platforms': {
            'android': {'enable': false},
            'web': {'enable': true},
          },
        }),
        isTrue,
      );
    });

    test('isNeedingNew*Icon requires the enable flag to be true', () {
      final platforms = {
        'android': {'enable': true},
        'ios': {'enable': false},
        'macos': <String, dynamic>{},
      };
      expect(isNeedingNewAndroidIcon(platforms), isTrue);
      expect(isNeedingNewIosIcon(platforms), isFalse);
      expect(isNeedingNewMacOSIcon(platforms), isFalse);
      expect(isNeedingNewWindowsIcon(platforms), isFalse);
      expect(isNeedingNewWebIcon(platforms), isFalse);
      expect(isNeedingNewLinuxIcon(platforms), isFalse);
    });

    test('has*Config checks key presence per platform', () {
      final platforms = {
        'android': {'enable': true},
        'windows': {'enable': true},
      };
      expect(hasAndroidConfig(platforms), isTrue);
      expect(hasWindowsConfig(platforms), isTrue);
      expect(hasIosConfig(platforms), isFalse);
      expect(hasMacOSConfig(platforms), isFalse);
      expect(hasLinuxConfig(platforms), isFalse);
      expect(hasWebConfig(platforms), isFalse);
    });

    test('hasAndroidAdaptiveConfig needs foreground and background config',
        () {
      expect(
        hasAndroidAdaptiveConfig({
          'android': {
            'enable': true,
            'adaptive_background_color': '#ffffff',
            'adaptive_foreground_image': 'fg.png',
          },
        }),
        isTrue,
      );
      expect(
        hasAndroidAdaptiveConfig({
          'android': {
            'enable': true,
            'adaptive_foreground_image': 'fg.png',
          },
        }),
        isFalse,
      );
      expect(
        hasAndroidAdaptiveConfig({
          'android': {
            'enable': true,
            'adaptive_background_image': 'bg.png',
          },
        }),
        isFalse,
      );
    });

    test('hasAndroidNotificationConfig checks the notification image key', () {
      expect(
        hasAndroidNotificationConfig({
          'android': {'enable': true, 'notification_image': 'n.png'},
        }),
        isTrue,
      );
      expect(
        hasAndroidNotificationConfig({
          'android': {'enable': true},
        }),
        isFalse,
      );
    });
  });

  group('isValidHexaCode', () {
    test('accepts 3- and 6-digit hex codes with a leading #', () {
      expect(isValidHexaCode('#fff'), isTrue);
      expect(isValidHexaCode('#FFFFFF'), isTrue);
      expect(isValidHexaCode('#1a2b3c'), isTrue);
    });

    test('rejects codes without a leading #', () {
      expect(isValidHexaCode('ffffff'), isFalse);
    });

    test('rejects codes with a wrong length', () {
      expect(isValidHexaCode('#ff'), isFalse);
      expect(isValidHexaCode('#fffff'), isFalse);
      expect(isValidHexaCode('#fffffff'), isFalse);
    });
  });

  group('isImageFile', () {
    test('accepts png, jpg and jpeg', () {
      expect(isImageFile('icon.png'), isTrue);
      expect(isImageFile('icon.jpg'), isTrue);
      expect(isImageFile('icon.jpeg'), isTrue);
    });

    test('rejects other extensions', () {
      expect(isImageFile('icon.gif'), isFalse);
      expect(isImageFile('icon.webp'), isFalse);
      expect(isImageFile('icon'), isFalse);
    });
  });

  group('getColorXmlContent', () {
    test('embeds the upper-cased color into the resource xml', () {
      final xml = getColorXmlContent('#a1b2c3');
      expect(xml, contains('<color name="ic_launcher_background">#A1B2C3'));
      expect(xml, contains('<resources>'));
    });
  });

  group('file helpers', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('icons_launcher_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('deleteFile removes an existing file', () {
      final file = File('${tempDir.path}/file.txt')..writeAsStringSync('x');

      expect(deleteFile(file.path), isTrue);
      expect(file.existsSync(), isFalse);
    });

    test('deleteFile returns false for a missing file', () {
      expect(deleteFile('${tempDir.path}/missing.txt'), isFalse);
    });

    test('removeDir removes a directory recursively', () {
      final dir = Directory('${tempDir.path}/a/b')..createSync(recursive: true);
      File('${dir.path}/file.txt').writeAsStringSync('x');

      expect(removeDir('${tempDir.path}/a'), isTrue);
      expect(Directory('${tempDir.path}/a').existsSync(), isFalse);
    });

    test('removeDir returns false for a missing directory', () {
      expect(removeDir('${tempDir.path}/missing'), isFalse);
    });
  });
}
