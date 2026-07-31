## 0.2.0

### Breaking
- Namespaced the bundled translation keys with `app_lang_selector:`.
- `PkgsAssetLoader` now merges the app's translations *over* the packages'.
  Previously a package key silently overrode a key of the same name defined by
  the app.

### Fixed
- Migrated off the `Radio.groupValue`/`Radio.onChanged` pair deprecated in
  Flutter 3.32; the page now uses a `RadioGroup` with `RadioListTile`.
- `LangCode.hashCode` uses `Object.hash` instead of XOR.

### Added
- `LangCode.system`, the sentinel for "follow the system language".

### Changed
- `langsNameMap` is now unmodifiable.

## 0.1.0+4

 - **CHORE**: upgrade riverpod_generator to ^4.0.0 and riverpod_lint to ^3.1.0.

## 0.1.0+3

 - **FIX**: resolve crash risks and stale state issues found in code review.
 - **FIX**: give example workspace members unique package names.
 - **FIX**: bump app_lang_selector example SDK to ^3.5.0 for workspace support.
 - **FIX**: include example apps as pub workspace members.
 - **FIX**: reset repo link and homepage link.
 - **FIX**: format and fix.
 - **FIX**: use melos.

## 0.1.0+2

 - **FIX**: give example workspace members unique package names.
 - **FIX**: bump app_lang_selector example SDK to ^3.5.0 for workspace support.
 - **FIX**: include example apps as pub workspace members.

## 0.1.0+1

 - **FIX**: reset repo link and homepage link.
 - **FIX**: format and fix.
 - **FIX**: use melos.

## 0.1.0

- Update riverpod dependencies.

## 0.0.3

- Fix import bug.

## 0.0.2

- Add support for tr-TR language

## 0.0.1

- Initial release of app_lang_selector
- ✨ Easy-to-use language selection widgets
- 🌍 Support for 40+ languages with native names
- 🎨 Material Design 3 compatible UI
- 🔄 Built-in Riverpod state management
- 📱 Responsive design for all screen sizes
- 🎯 Seamless integration with easy_localization
- 📦 Complete example app included
- 📚 Comprehensive documentation and README

### Features

- `AppLangSelectTile`: Ready-to-use ListTile for settings pages
- `AppLangSelectPage`: Full-screen language selection page
- `selectingLangProvider`: Riverpod provider for state management
- `LangCode`: Helper class for language code management
- `langsNameMap`: Comprehensive mapping of language codes to native names

### Supported Languages

English, 日本語, 简体中文, 繁體中文, 한국어, Español, Français, Deutsch, Italiano, Português, Русский, العربية, Tiếng Việt, हिंदी, Polski, Nederlands, Türkçe, Українська, Svenska, Română, עברית, Български, Čeština, Dansk, Ελληνικά, Suomi, Magyar, Norsk, Slovenčina, Slovenščina, Српски, اردو, မြန်မာစာ, Kiswahili, Filipino, አማርኛ, پښتو, and more.
