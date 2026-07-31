import 'dart:convert';
import 'dart:io';

import 'package:colaxy_localization/colaxy_localization.dart';
import 'package:test/test.dart';

/// The minimum set of keys `fitAllToFastlane` needs.
Map<String, String> _validJson({Map<String, String> overrides = const {}}) => {
      'app_name': 'Demo',
      'store_app_name': 'Demo',
      'store_description': 'A description.',
      'store_ios_subtitle': 'Subtitle',
      'store_android_short_description': 'Short description',
      'store_release_note': 'Notes',
      'store_ios_keywords': 'notes,todo,list',
      'store_ios_promotional_text': 'Promo',
      'store_ios_support_url': 'https://example.com/support',
      'store_ios_privacy_url': 'https://example.com/privacy',
      ...overrides,
    };

late Directory _root;

/// Writes `<root>/assets/localizations/<locale>.json`.
void _writeLocale(String locale, Map<String, String> data) {
  File('${_root.path}/assets/localizations/$locale.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(json.encode(data));
}

void main() {
  setUp(() {
    _root = Directory.systemTemp.createTempSync('colaxy_localization_test');
  });
  tearDown(() => _root.deleteSync(recursive: true));

  group('locale mapping', () {
    test('exposes the App Store locale for a mapped locale', () {
      _writeLocale('ja-JP', _validJson());
      final unit = LocaleUnit(locale: 'ja-JP', rootPath: _root.path);

      expect(unit.iosLocale, 'ja');
    });

    test('explains which locales are supported instead of a null crash', () {
      _writeLocale('de-DE', _validJson());
      final unit = LocaleUnit(locale: 'de-DE', rootPath: _root.path);

      // `iosLocaleMap[locale]!` used to throw a bare null-check error naming
      // neither the locale nor the map.
      expect(
        () => unit.iosLocale,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('de-DE'), contains('ja-JP')),
          ),
        ),
      );
    });
  });

  group('missing input', () {
    test('names the file that is missing', () {
      final unit = LocaleUnit(locale: 'en-US', rootPath: _root.path);

      expect(
        unit.fitAllToFastlane,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('en-US.json'),
          ),
        ),
      );
    });

    test('names the key that is missing', () {
      final incomplete = _validJson()..remove('store_ios_keywords');
      _writeLocale('en-US', incomplete);
      final unit = LocaleUnit(locale: 'en-US', rootPath: _root.path);

      expect(
        unit.fitAllToFastlane,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('store_ios_keywords'),
          ),
        ),
      );
    });
  });

  group('length limits', () {
    test('rejects an app name over 30 characters', () {
      _writeLocale('en-US', _validJson(overrides: {'app_name': 'x' * 31}));
      final unit = LocaleUnit(locale: 'en-US', rootPath: _root.path);

      expect(unit.fitAllToFastlane, throwsA(isA<StateError>()));
    });

    test('rejects a short description over 80 characters', () {
      _writeLocale(
        'en-US',
        _validJson(overrides: {'store_android_short_description': 'x' * 81}),
      );
      final unit = LocaleUnit(locale: 'en-US', rootPath: _root.path);

      expect(unit.fitAllToFastlane, throwsA(isA<StateError>()));
    });
  });

  group('keyword trademark check', () {
    /// Runs the pipeline and returns the message of whatever it threw.
    ///
    /// Later stages need an Android/iOS project on disk, so they fail too;
    /// asserting on the message keeps this focused on the keyword check.
    String? errorFor(String keywords) {
      _writeLocale(
        'en-US',
        _validJson(overrides: {'store_ios_keywords': keywords}),
      );
      final unit = LocaleUnit(locale: 'en-US', rootPath: _root.path);
      try {
        unit.fitAllToFastlane();
        return null;
        // The package signals invalid input with StateError, so the test has
        // to catch it to inspect the message.
        // ignore: avoid_catching_errors
      } on StateError catch (e) {
        return e.message;
      }
    }

    test('catches a trademark regardless of case', () {
      // `contains('ios')` used to miss the capitalised spelling entirely.
      expect(errorFor('notes,iOS,todo'), contains('blocked trademarks: ios'));
      expect(
        errorFor('notes,Google,todo'),
        contains('blocked trademarks: google'),
      );
    });

    test('does not flag a word that merely contains a trademark', () {
      // `contains('ios')` used to reject "radios".
      expect(errorFor('radios,notes,todo'), isNot(contains('trademarks')));
    });
  });
}
