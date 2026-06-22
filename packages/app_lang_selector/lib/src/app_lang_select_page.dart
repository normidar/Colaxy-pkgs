import 'package:app_lang_selector/src/selecting_lang/selecting_lang.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final langsNameMap = {
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
    final selectedLang = ref.watch<String?>(selectingLangProvider) ??
        context.savedLocale?.languageCode ??
        'system_system';
    return Scaffold(
      appBar: AppBar(title: Text('select_lang_page'.tr())),
      body: ListView(
        children: [
          ListTile(
            onTap: () async {
              Intl.defaultLocale = context.locale.languageCode;
              await context.resetLocale();
              ref
                  .read<SelectingLang>(selectingLangProvider.notifier)
                  .setLang('system_system');
            },
            leading: Radio(
              value: 'system_system',
              groupValue: selectedLang,
              onChanged: (v) async {
                Intl.defaultLocale = context.locale.languageCode;
                await context.resetLocale();
                ref
                    .read<SelectingLang>(selectingLangProvider.notifier)
                    .setLang('system_system');
              },
            ),
            title: Text('follow_system'.tr()),
          ),
          ...context.supportedLocales.map(
            (e) => ListTile(
              title:
                  Text(langsNameMap[LangCode.fromLocale(e)] ?? e.languageCode),
              leading: Radio<LangCode>(
                value: LangCode.fromLocale(e),
                groupValue: LangCode.fromString(selectedLang),
                onChanged: (value) async {
                  if (value != null) {
                    Intl.defaultLocale = value.languageCode;
                    await context.setLocale(value.toLocale());
                    ref
                        .read<SelectingLang>(selectingLangProvider.notifier)
                        .setLang(value.toString());
                  }
                },
              ),
              onTap: () async {
                Intl.defaultLocale = e.languageCode;
                await context.setLocale(e);
                ref
                    .read<SelectingLang>(selectingLangProvider.notifier)
                    .setLang(LangCode.fromLocale(e).toString());
              },
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class LangCode {
  const LangCode({required this.languageCode, required this.countryCode});
  factory LangCode.fromLocale(Locale locale) {
    return LangCode(
      languageCode: locale.languageCode,
      countryCode: locale.countryCode!,
    );
  }

  factory LangCode.fromString(String langCode) {
    final parts = langCode.split('_');
    if (parts.length == 1) {
      return const LangCode(languageCode: 'system', countryCode: 'system');
    }
    return LangCode(languageCode: parts[0], countryCode: parts[1]);
  }

  final String languageCode;

  final String countryCode;

  @override
  int get hashCode => languageCode.hashCode ^ countryCode.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is LangCode) {
      return languageCode == other.languageCode &&
          countryCode == other.countryCode;
    }
    return false;
  }

  Locale toLocale() {
    return Locale(languageCode, countryCode);
  }

  @override
  String toString() {
    return '${languageCode}_$countryCode';
  }
}
