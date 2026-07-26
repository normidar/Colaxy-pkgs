import 'dart:convert';
import 'dart:io';

import 'package:colaxy_localization/colaxy_localization.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

const _androidManifest = '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- a comment to be removed -->
    <application android:label="old_label" android:name="app">
    </application>
</manifest>
''';

const _infoPlist = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>runner</string>
</dict>
</plist>
''';

Map<String, String> _localeJson(String suffix) {
  return {
    'app_name': 'App $suffix',
    'store_app_name': 'Store App $suffix',
    'store_description': 'A description $suffix',
    'store_ios_subtitle': 'Subtitle $suffix',
    'store_android_short_description': 'Short description $suffix',
    'store_release_note': 'Release note $suffix',
    'store_ios_keywords': 'keyword1,keyword2',
    'store_ios_promotional_text': 'Promo $suffix',
    'store_ios_support_url': 'https://example.com/support',
    'store_ios_privacy_url': 'https://example.com/privacy',
  };
}

void main() {
  late Directory originalDir;
  late Directory tempDir;

  setUp(() {
    originalDir = Directory.current;
    tempDir = Directory.systemTemp.createTempSync('colaxy_localization_test');
    Directory.current = tempDir;
  });

  tearDown(() {
    Directory.current = originalDir;
    tempDir.deleteSync(recursive: true);
  });

  void writeLocaleJson(String locale, Map<String, String> json) {
    File('assets/localizations/$locale.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(json));
  }

  void writeAndroidManifest() {
    File('android/app/src/main/AndroidManifest.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync(_androidManifest);
  }

  void writeInfoPlist() {
    File('ios/Runner/Info.plist')
      ..createSync(recursive: true)
      ..writeAsStringSync(_infoPlist);
  }

  group('AndroidNameLocalization', () {
    test('fitLocale writes strings.xml for the default locale', () {
      const AndroidNameLocalization().fitLocale(appName: 'My App');

      final file = File('android/app/src/main/res/values/strings.xml');
      expect(file.existsSync(), isTrue);
      final xml = XmlDocument.parse(file.readAsStringSync());
      final string = xml.findAllElements('string').first;
      expect(string.getAttribute('name'), 'app_name');
      expect(string.innerText, 'My App');
    });

    test('fitLocale writes into the mapped locale folder', () {
      const AndroidNameLocalization()
          .fitLocale(appName: '私のアプリ', locale: 'ja-JP');

      final file = File('android/app/src/main/res/values-ja/strings.xml');
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('私のアプリ'));
    });

    test('fitLocale maps zh-CN to values-zh-rCN', () {
      const AndroidNameLocalization()
          .fitLocale(appName: '我的应用', locale: 'zh-CN');

      expect(
        File('android/app/src/main/res/values-zh-rCN/strings.xml')
            .existsSync(),
        isTrue,
      );
    });

    test('updateManifestAppName points the label at the string resource', () {
      writeAndroidManifest();

      const AndroidNameLocalization().updateManifestAppName();

      final content =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final xml = XmlDocument.parse(content);
      final application = xml.findAllElements('application').first;
      expect(application.getAttribute('android:label'), '@string/app_name');
      expect(content, isNot(contains('a comment to be removed')));
    });
  });

  group('IOSNameLocalization', () {
    test('fitLocale writes InfoPlist.strings for a locale', () {
      const IOSNameLocalization()
          .fitLocale(appName: 'My App', locale: 'en-US');

      final file = File('ios/Runner/en-US.lproj/InfoPlist.strings');
      expect(file.existsSync(), isTrue);
      expect(
        file.readAsStringSync(),
        'CFBundleDisplayName = "My App";\n',
      );
    });

    test('fitLocale maps zh-CN to the zh-Hans folder', () {
      const IOSNameLocalization()
          .fitLocale(appName: '我的应用', locale: 'zh-CN');

      expect(
        File('ios/Runner/zh-Hans.lproj/InfoPlist.strings').existsSync(),
        isTrue,
      );
    });

    test('fitLocale without a locale adds CFBundleDisplayName to Info.plist',
        () {
      writeInfoPlist();

      const IOSNameLocalization().fitLocale(appName: 'My App');

      final content = File('ios/Runner/Info.plist').readAsStringSync();
      final xml = XmlDocument.parse(content);
      final dict = xml.rootElement.findElements('dict').first;
      final keys = dict.findElements('key').map((e) => e.innerText).toList();
      expect(keys, contains('CFBundleDisplayName'));
      expect(content, contains('My App'));
    });

    test('updateInfoPlistAppName replaces an existing display name', () {
      File('ios/Runner/Info.plist')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key>
	<string>Old Name</string>
</dict>
</plist>
''');

      const IOSNameLocalization().updateInfoPlistAppName('New Name');

      final content = File('ios/Runner/Info.plist').readAsStringSync();
      expect(content, contains('New Name'));
      expect(content, isNot(contains('Old Name')));
    });

    test('fitAppSupportLocales writes sorted CFBundleLocalizations', () {
      writeInfoPlist();

      const IOSNameLocalization()
          .fitAppSupportLocales(['ja-JP', 'en-US', 'zh-CN']);

      final content = File('ios/Runner/Info.plist').readAsStringSync();
      final xml = XmlDocument.parse(content);
      final dict = xml.rootElement.findElements('dict').first;
      final keys = dict.findElements('key').toList();
      final localizationsKey = keys
          .firstWhere((key) => key.innerText == 'CFBundleLocalizations');
      final array = localizationsKey.nextElementSibling!;
      final locales =
          array.findElements('string').map((e) => e.innerText).toList();
      // ja-JP maps to ja, zh-CN maps to zh-Hans, then everything is sorted.
      expect(locales, ['en-US', 'ja', 'zh-Hans']);
    });
  });

  group('LocaleUnit', () {
    test('iosLocaleMap maps store locales to Apple shortcodes', () {
      expect(LocaleUnit.iosLocaleMap['zh-CN'], 'zh-Hans');
      expect(LocaleUnit.iosLocaleMap['zh-TW'], 'zh-Hant');
      expect(LocaleUnit.iosLocaleMap['ja-JP'], 'ja');
      expect(LocaleUnit.iosLocaleMap['en-US'], 'en-US');
    });

    test('fitAllToFastlane writes all metadata files', () {
      writeLocaleJson('en-US', _localeJson('EN'));
      writeAndroidManifest();
      writeInfoPlist();

      LocaleUnit(locale: 'en-US')
        ..isMainLocale = true
        ..fitAllToFastlane();

      expect(
        File('fastlane/metadata/android/en-US/title.txt').readAsStringSync(),
        'Store App EN',
      );
      expect(
        File('fastlane/metadata/en-US/name.txt').readAsStringSync(),
        'Store App EN',
      );
      expect(
        File('fastlane/metadata/android/en-US/full_description.txt')
            .readAsStringSync(),
        'A description EN',
      );
      expect(
        File('fastlane/metadata/en-US/subtitle.txt').readAsStringSync(),
        'Subtitle EN',
      );
      expect(
        File('fastlane/metadata/android/en-US/short_description.txt')
            .readAsStringSync(),
        'Short description EN',
      );
      expect(
        File('fastlane/metadata/android/en-US/changelogs/default.txt')
            .readAsStringSync(),
        'Release note EN',
      );
      expect(
        File('fastlane/metadata/en-US/keywords.txt').readAsStringSync(),
        'keyword1,keyword2',
      );
      expect(
        File('fastlane/metadata/en-US/promotional_text.txt')
            .readAsStringSync(),
        'Promo EN',
      );
      expect(
        File('fastlane/metadata/en-US/support_url.txt').readAsStringSync(),
        'https://example.com/support',
      );
      expect(
        File('fastlane/metadata/en-US/privacy_url.txt').readAsStringSync(),
        'https://example.com/privacy',
      );
      // The main locale also writes the native app names.
      expect(
        File('android/app/src/main/res/values/strings.xml').existsSync(),
        isTrue,
      );
    });

    test('appends the minimum version to descriptions when configured', () {
      writeLocaleJson('en-US', _localeJson('EN'));
      writeAndroidManifest();
      writeInfoPlist();
      File('pubspec.yaml').writeAsStringSync('minimum_version: 1.2.0\n');

      LocaleUnit(locale: 'en-US')
        ..isMainLocale = true
        ..fitAllToFastlane();

      expect(
        File('fastlane/metadata/android/en-US/full_description.txt')
            .readAsStringSync(),
        contains('[Minimum supported app version: 1.2.0]'),
      );
      expect(
        File('fastlane/metadata/en-US/description.txt').readAsStringSync(),
        contains('[:mav: 1.2.0]'),
      );
    });

    test('throws when app_name exceeds 30 characters', () {
      final json = _localeJson('EN');
      json['app_name'] = 'A' * 31;
      writeLocaleJson('en-US', json);
      writeAndroidManifest();
      writeInfoPlist();

      final unit = LocaleUnit(locale: 'en-US')..isMainLocale = true;
      expect(unit.fitAllToFastlane, throwsException);
    });

    test('throws when store keywords contain a blacklisted word', () {
      final json = _localeJson('EN');
      json['store_ios_keywords'] = 'apple,banana';
      writeLocaleJson('en-US', json);
      writeAndroidManifest();
      writeInfoPlist();

      final unit = LocaleUnit(locale: 'en-US')..isMainLocale = true;
      expect(unit.fitAllToFastlane, throwsException);
    });

    test('throws when the locale json file does not exist', () {
      final unit = LocaleUnit(locale: 'missing');
      expect(unit.fitAllToFastlane, throwsException);
    });
  });

  group('LocaleApp', () {
    test('getMinimumVersion returns null without a pubspec.yaml', () {
      expect(const LocaleApp().getMinimumVersion(), isNull);
    });

    test('getMinimumVersion reads the value from pubspec.yaml', () {
      File('pubspec.yaml').writeAsStringSync('minimum_version: 2.0.0\n');
      expect(const LocaleApp().getMinimumVersion(), '2.0.0');
    });

    test('getLocaleUnits marks en-US as the main locale', () {
      writeLocaleJson('en-US', _localeJson('EN'));
      writeLocaleJson('ja-JP', _localeJson('JA'));
      writeAndroidManifest();
      writeInfoPlist();

      final units = const LocaleApp().getLocaleUnits();

      expect(units, hasLength(2));
      final mainUnit = units.firstWhere((u) => u.isMainLocale);
      expect(mainUnit.locale, 'en-US');
    });

    test('getLocaleUnits marks a single locale as the main locale', () {
      writeLocaleJson('ja-JP', _localeJson('JA'));
      writeAndroidManifest();
      writeInfoPlist();

      final units = const LocaleApp().getLocaleUnits();

      expect(units, hasLength(1));
      expect(units.single.isMainLocale, isTrue);
    });

    test('getLocaleUnits throws when the localization dir is missing', () {
      writeAndroidManifest();
      expect(const LocaleApp().getLocaleUnits, throwsException);
    });
  });
}
