import 'dart:async';

import 'package:app_lang_selector/src/selecting_lang/selecting_lang.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Display names for the languages this package knows about, keyed by locale.
///
/// This is only a lookup table for rendering each entry in the *host app's*
/// `supportedLocales`; it does not mean this package ships a translation for
/// every one of them. The selector page itself is translated into the locales
/// under `assets/localizations/` ([bundledLocales]) — for anything else the
/// page chrome falls back to easy_localization's `fallbackLocale`.
///
/// Wrapped in an unmodifiable map: it is public API, and callers must not be
/// able to mutate the shared table.
final langsNameMap = Map<LangCode, String>.unmodifiable(_langsNameMap);

/// The locales this package ships its own translations for.
final bundledLocales = <LangCode>{
  const LangCode(languageCode: 'ar', countryCode: 'AE'),
  const LangCode(languageCode: 'de', countryCode: 'DE'),
  const LangCode(languageCode: 'en', countryCode: 'US'),
  const LangCode(languageCode: 'es', countryCode: 'ES'),
  const LangCode(languageCode: 'fr', countryCode: 'FR'),
  const LangCode(languageCode: 'it', countryCode: 'IT'),
  const LangCode(languageCode: 'ja', countryCode: 'JP'),
  const LangCode(languageCode: 'ko', countryCode: 'KR'),
  const LangCode(languageCode: 'pt', countryCode: 'PT'),
  const LangCode(languageCode: 'ru', countryCode: 'RU'),
  const LangCode(languageCode: 'tr', countryCode: 'TR'),
  const LangCode(languageCode: 'vi', countryCode: 'VN'),
  const LangCode(languageCode: 'zh', countryCode: 'CN'),
  const LangCode(languageCode: 'zh', countryCode: 'TW'),
};

final _langsNameMap = <LangCode, String>{
  const LangCode(languageCode: 'en', countryCode: 'US'): 'English',
  const LangCode(languageCode: 'ja', countryCode: 'JP'): '日本語',
  const LangCode(languageCode: 'zh', countryCode: 'CN'): '简体中文',
  const LangCode(languageCode: 'zh', countryCode: 'TW'): '繁體中文',
  const LangCode(languageCode: 'ko', countryCode: 'KR'): '한국어',
  const LangCode(languageCode: 'vi', countryCode: 'VN'): 'Tiếng Việt',
  const LangCode(languageCode: 'ru', countryCode: 'RU'): 'Русский',
  const LangCode(languageCode: 'es', countryCode: 'ES'): 'Español',
  const LangCode(languageCode: 'fr', countryCode: 'FR'): 'Français',
  const LangCode(languageCode: 'de', countryCode: 'DE'): 'Deutsch',
  const LangCode(languageCode: 'it', countryCode: 'IT'): 'Italiano',
  const LangCode(languageCode: 'pt', countryCode: 'PT'): 'Português',
  const LangCode(languageCode: 'id', countryCode: 'ID'): 'Bahasa Indonesia',
  const LangCode(languageCode: 'pl', countryCode: 'PL'): 'Polski',
  const LangCode(languageCode: 'nl', countryCode: 'NL'): 'Nederlands',
  const LangCode(languageCode: 'tr', countryCode: 'TR'): 'Türkçe',
  const LangCode(languageCode: 'uk', countryCode: 'UA'): 'Українська',
  const LangCode(languageCode: 'ar', countryCode: 'AE'): 'العربية',
  const LangCode(languageCode: 'sv', countryCode: 'SE'): 'Svenska',
  const LangCode(languageCode: 'hi', countryCode: 'IN'): 'हिंदी',
  const LangCode(languageCode: 'ro', countryCode: 'RO'): 'Română',
  const LangCode(languageCode: 'he', countryCode: 'IL'): 'עברית',
  const LangCode(languageCode: 'bg', countryCode: 'BG'): 'Български',
  const LangCode(languageCode: 'cs', countryCode: 'CZ'): 'Čeština',
  const LangCode(languageCode: 'da', countryCode: 'DK'): 'Dansk',
  const LangCode(languageCode: 'el', countryCode: 'GR'): 'Ελληνικά',
  const LangCode(languageCode: 'fi', countryCode: 'FI'): 'Suomi',
  const LangCode(languageCode: 'hu', countryCode: 'HU'): 'Magyar',
  const LangCode(languageCode: 'no', countryCode: 'NO'): 'Norsk',
  const LangCode(languageCode: 'sk', countryCode: 'SK'): 'Slovenčina',
  const LangCode(languageCode: 'sl', countryCode: 'SI'): 'Slovenščina',
  const LangCode(languageCode: 'sr', countryCode: 'RS'): 'Српски',
  const LangCode(languageCode: 'ur', countryCode: 'PK'): 'اردو',
  const LangCode(languageCode: 'my', countryCode: 'MM'): 'မြန်မာစာ',
  const LangCode(languageCode: 'sw', countryCode: 'KE'): 'Kiswahili',
  const LangCode(languageCode: 'tl', countryCode: 'PH'): 'Filipino',
  const LangCode(languageCode: 'am', countryCode: 'ET'): 'አማርኛ',
  const LangCode(languageCode: 'ps', countryCode: 'AF'): 'پښتو',
};

/// 言語を選択するページ
class AppLangSelectPage extends ConsumerWidget {
  const AppLangSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLang =
        ref.watch<String?>(selectingLangProvider) ??
        context.savedLocale?.toString() ??
        LangCode.system.toString();
    return Scaffold(
      appBar: AppBar(title: Text('app_lang_selector:select_lang_page'.tr())),
      // `Radio.groupValue`/`Radio.onChanged` were deprecated in Flutter 3.32 in
      // favour of a `RadioGroup` ancestor. Going through RadioListTile also
      // means the selection logic lives in one place instead of being copied
      // into each tile's `onTap` and each radio's `onChanged`.
      body: RadioGroup<LangCode>(
        groupValue: LangCode.fromString(selectedLang),
        onChanged: (value) => unawaited(_select(context, ref, value)),
        child: ListView(
          children: [
            RadioListTile<LangCode>(
              value: LangCode.system,
              title: Text('app_lang_selector:follow_system'.tr()),
            ),
            ...context.supportedLocales.map(
              (e) => RadioListTile<LangCode>(
                value: LangCode.fromLocale(e),
                title: Text(
                  langsNameMap[LangCode.fromLocale(e)] ?? e.languageCode,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Applies [value] as the app's language and remembers the choice.
  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    LangCode? value,
  ) async {
    if (value == null) return;
    if (value == LangCode.system) {
      Intl.defaultLocale = context.locale.languageCode;
      await context.resetLocale();
    } else {
      Intl.defaultLocale = value.languageCode;
      await context.setLocale(value.toLocale());
    }
    // This runs unawaited, so `ref` may outlive the page if it was popped
    // during the locale change; reading a disposed ref throws into the zone.
    if (!context.mounted) return;
    ref
        .read<SelectingLang>(selectingLangProvider.notifier)
        .setLang(value.toString());
  }
}

@immutable
class LangCode {
  const LangCode({required this.languageCode, required this.countryCode});
  factory LangCode.fromLocale(Locale locale) {
    return LangCode(
      languageCode: locale.languageCode,
      countryCode: locale.countryCode ?? '',
    );
  }

  factory LangCode.fromString(String langCode) {
    final parts = langCode.split('_');
    if (parts.length == 1) {
      return LangCode(languageCode: parts[0], countryCode: '');
    }
    return LangCode(languageCode: parts[0], countryCode: parts[1]);
  }

  /// Sentinel meaning "follow the system language" rather than a real locale.
  ///
  /// Its [toString] is `system_system`, which is the value that has always been
  /// persisted for this option.
  static const system = LangCode(
    languageCode: 'system',
    countryCode: 'system',
  );

  final String languageCode;

  final String countryCode;

  @override
  int get hashCode => Object.hash(languageCode, countryCode);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LangCode &&
        languageCode == other.languageCode &&
        countryCode == other.countryCode;
  }

  Locale toLocale() {
    return countryCode.isEmpty
        ? Locale(languageCode)
        : Locale(languageCode, countryCode);
  }

  @override
  String toString() {
    return countryCode.isEmpty ? languageCode : '${languageCode}_$countryCode';
  }
}
