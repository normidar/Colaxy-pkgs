# app_lang_selector

[![GitHub](https://img.shields.io/github/license/normidar/app_lang_selector.svg)](https://github.com/normidar/app_lang_selector/blob/main/LICENSE)
[![pub package](https://img.shields.io/pub/v/app_lang_selector.svg)](https://pub.dartlang.org/packages/app_lang_selector)
[![GitHub Stars](https://img.shields.io/github/stars/normidar/app_lang_selector.svg)](https://github.com/normidar/app_lang_selector/stargazers)
[![Twitter](https://img.shields.io/twitter/url/https/twitter.com/normidar.svg?style=social&label=Follow%20%40normidar)](https://twitter.com/normidar2)
[![Github-sponsors](https://img.shields.io/badge/sponsor-30363D?logo=GitHub-Sponsors&logoColor=#EA4AAA)](https://github.com/sponsors/normidar)

A Flutter package for easy language selection with beautiful UI and state management support. This package provides ready-to-use widgets for language selection with support for multiple languages and seamless integration with `easy_localization` and `riverpod`. The package includes built-in localization assets that can be automatically merged with your app's localizations.

## Features

✨ **Easy Integration**: Drop-in widgets for language selection  
🌍 **Multi-language Support**: Supports 40+ languages with native names  
🎨 **Beautiful UI**: Material Design 3 compatible interface  
📱 **Responsive Design**: Works on all screen sizes  
🔄 **State Management**: Built-in Riverpod state management  
⚡ **Fast Performance**: Optimized for smooth user experience  
🎯 **Easy Localization**: Seamless integration with easy_localization package  
📦 **Built-in Assets**: Package includes localization files that auto-merge with your app's translations

## Supported Languages

The package includes native names for 40+ languages including:

- English, 日本語, 简体中文, 繁體中文, 한국어
- Español, Français, Deutsch, Italiano, Português
- Русский, العربية, Tiếng Việt, हिंदी, Polski
- And many more...

## Getting Started

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  app_lang_selector: ^0.0.3
  easy_localization: ^3.0.7
  flutter_riverpod: ^2.6.1
```

Then run:

```bash
flutter pub get
```

### Asset Setup

The package includes built-in localization files. Make sure your `pubspec.yaml` includes the localization assets path:

```yaml
flutter:
  assets:
    - assets/localizations/
```

### Basic Setup

1. **Wrap your app with required providers:**

```dart
import 'package:app_lang_selector/app_lang_selector.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ja', 'JP'),
        Locale('zh', 'CN'),
        Locale('ko', 'KR'),
        Locale('es', 'ES'),
        Locale('fr', 'FR'),
        // Add your supported locales
      ],
      path: 'assets/localizations',
      // IMPORTANT: Use PkgsAssetLoader to merge package localizations with your app's
      assetLoader: const PkgsAssetLoader(packages: [
        packageName,
      ]),
      fallbackLocale: const Locale('en', 'US'),
      child: const ProviderScope(
        child: MyApp(),
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Your App Title',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const YourHomePage(),
    );
  }
}
```

**Important:** The `PkgsAssetLoader` is required to merge the package's built-in localization files (for the language selector UI) with your app's localization files. The `packageName` constant is exported from this package.

2. **Add language selection to your UI:**

```dart
// Simple tile for settings page
const AppLangSelectTile()

// Or use the full page directly
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const AppLangSelectPage(),
  ),
);
```

The `AppLangSelectTile` displays a list tile with a language icon and title. When tapped, it navigates to the `AppLangSelectPage` where users can select their preferred language.

## Localization Keys

The package includes built-in localization files with the following keys. When using `PkgsAssetLoader`, these will automatically merge with your app's localizations:

- `select_lang`: "Select Language" - Title for the language selection tile
- `select_lang_page`: "Language Selection" - Title for the language selection page  
- `follow_system`: "Follow System" - Text for the system language option

The package provides these translations in 12+ languages. You can override them in your own localization files, or use the provided translations by including `PkgsAssetLoader` in your setup. See the `assets/localizations/` directory for all available translations.

## Example App

A complete example app is included in the `example/` directory. To run it:

```bash
cd example
flutter pub get
flutter run
```

The example demonstrates:

- Complete app setup with multiple languages
- Integration with `easy_localization` and `riverpod`
- Using `PkgsAssetLoader` to merge package localizations
- Language selection UI with `AppLangSelectTile` and `AppLangSelectPage`
- State persistence across app restarts

## Advanced Usage

### Accessing Current Language Selection

The package uses Riverpod for state management. You can access and observe the current language selection in your widgets:

```dart
class YourWidget extends ConsumerWidget {
  const YourWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the current selected language
    final selectedLang = ref.watch(selectingLangProvider);
    
    // Use it in your UI
    return Text('Current: $selectedLang');
  }
}
```

The `selectingLangProvider` returns a `String?` in the format `languageCode_countryCode` (e.g., `"en_US"`, `"ja_JP"`), or `"system_system"` if following the system language, or `null` if not yet set.

### Language Names Map

The package includes a comprehensive `langsNameMap` with native names for 40+ languages. This map is used internally by `AppLangSelectPage` to display language names. The map includes:

```dart
final langsNameMap = {
  const LangCode(languageCode: 'en', countryCode: 'US'): 'English',
  const LangCode(languageCode: 'ja', countryCode: 'JP'): '日本語',
  const LangCode(languageCode: 'zh', countryCode: 'CN'): '简体中文',
  const LangCode(languageCode: 'zh', countryCode: 'TW'): '繁體中文',
  const LangCode(languageCode: 'ko', countryCode: 'KR'): '한국어',
  // ... and many more
};
```

### LangCode Utility Class

The package provides a `LangCode` class for working with language codes:

```dart
// Create from Locale
final langCode = LangCode.fromLocale(Locale('en', 'US'));

// Create from string
final langCode = LangCode.fromString('en_US');

// Convert to Locale
final locale = langCode.toLocale();

// Convert to string
final string = langCode.toString(); // Returns 'en_US'
```

### Programmatic Language Change

You can programmatically change the language using the provider:

```dart
// Change to a specific language
ref.read(selectingLangProvider.notifier).setLang('ja_JP');
await context.setLocale(const Locale('ja', 'JP'));

// Reset to system language
ref.read(selectingLangProvider.notifier).setLang('system_system');
await context.resetLocale();
```

## API Reference

### Widgets

- **`AppLangSelectTile`**: A `ListTile` widget that displays the language selection option and navigates to the language selection page when tapped.
- **`AppLangSelectPage`**: A full-page widget that displays all available languages with radio buttons for selection. Includes a "Follow System" option.

### Providers

- **`selectingLangProvider`**: A Riverpod provider that manages the current language selection state. Returns `String?` with values like `"en_US"`, `"ja_JP"`, or `"system_system"`.

### Classes

- **`LangCode`**: Utility class for working with language codes. Provides conversion between `Locale` and string formats.
- **`PkgsAssetLoader`**: Custom `AssetLoader` for `easy_localization` that merges package localization files with app localization files.

### Constants

- **`packageName`**: The package name string (`"app_lang_selector"`) used with `PkgsAssetLoader`.
- **`langsNameMap`**: A map of `LangCode` to native language names for 40+ languages.

## Requirements

- Flutter >=1.17.0
- Dart >=3.0.0
- easy_localization ^3.0.7
- flutter_riverpod ^2.6.1

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you find this package helpful, please consider giving it a ⭐ on [GitHub](https://github.com/normidar/app_lang_selector)!
