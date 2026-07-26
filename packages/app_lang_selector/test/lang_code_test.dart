import 'dart:ui';

import 'package:app_lang_selector/app_lang_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LangCode.fromString', () {
    test('parses language and country code', () {
      final code = LangCode.fromString('ja_JP');
      expect(code.languageCode, 'ja');
      expect(code.countryCode, 'JP');
    });

    test('parses a language-only string', () {
      final code = LangCode.fromString('en');
      expect(code.languageCode, 'en');
      expect(code.countryCode, '');
    });
  });

  group('LangCode.fromLocale', () {
    test('uses language and country code from the locale', () {
      final code = LangCode.fromLocale(const Locale('zh', 'TW'));
      expect(code.languageCode, 'zh');
      expect(code.countryCode, 'TW');
    });

    test('falls back to an empty country code', () {
      final code = LangCode.fromLocale(const Locale('en'));
      expect(code.countryCode, '');
    });
  });

  group('LangCode.toString', () {
    test('joins language and country with an underscore', () {
      expect(
        const LangCode(languageCode: 'ja', countryCode: 'JP').toString(),
        'ja_JP',
      );
    });

    test('omits the separator when country code is empty', () {
      expect(
        const LangCode(languageCode: 'en', countryCode: '').toString(),
        'en',
      );
    });
  });

  group('LangCode.toLocale', () {
    test('creates a locale with a country code', () {
      expect(
        const LangCode(languageCode: 'ja', countryCode: 'JP').toLocale(),
        const Locale('ja', 'JP'),
      );
    });

    test('creates a language-only locale when country code is empty', () {
      expect(
        const LangCode(languageCode: 'en', countryCode: '').toLocale(),
        const Locale('en'),
      );
    });
  });

  group('LangCode equality', () {
    test('equal values are equal and share a hash code', () {
      const a = LangCode(languageCode: 'ja', countryCode: 'JP');
      const b = LangCode(languageCode: 'ja', countryCode: 'JP');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different values are not equal', () {
      const a = LangCode(languageCode: 'ja', countryCode: 'JP');
      const b = LangCode(languageCode: 'zh', countryCode: 'CN');
      expect(a, isNot(b));
      expect(a, isNot('ja_JP'));
    });

    test('round-trips through toString and fromString', () {
      const original = LangCode(languageCode: 'zh', countryCode: 'TW');
      expect(LangCode.fromString(original.toString()), original);
    });
  });

  group('langsNameMap', () {
    test('contains major languages', () {
      expect(
        langsNameMap[const LangCode(languageCode: 'en', countryCode: 'US')],
        'English',
      );
      expect(
        langsNameMap[const LangCode(languageCode: 'ja', countryCode: 'JP')],
        '日本語',
      );
      expect(
        langsNameMap[const LangCode(languageCode: 'zh', countryCode: 'CN')],
        '简体中文',
      );
    });

    test('all display names are non-empty and unique', () {
      final names = langsNameMap.values.toList();
      expect(names.any((name) => name.isEmpty), isFalse);
      expect(names.toSet().length, names.length);
    });
  });
}
