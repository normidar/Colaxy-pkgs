# app_info_tile

[![GitHub](https://img.shields.io/github/license/normidar/app_info_tile.svg)](https://github.com/normidar/app_info_tile/blob/main/LICENSE)
[![pub package](https://img.shields.io/pub/v/app_info_tile.svg)](https://pub.dartlang.org/packages/app_info_tile)
[![GitHub Stars](https://img.shields.io/github/stars/normidar/app_info_tile.svg)](https://github.com/normidar/app_info_tile/stargazers)
[![Twitter](https://img.shields.io/twitter/url/https/twitter.com/normidar.svg?style=social&label=Follow%20%40normidar)](https://twitter.com/normidar)
[![Github-sponsors](https://img.shields.io/badge/sponsor-30363D?logo=GitHub-Sponsors&logoColor=#EA4AAA)](https://github.com/sponsors/normidar)

A Flutter package that provides a simple and elegant way to display app information with license viewing capabilities. Perfect for settings screens and about pages.

## Features

- 📱 **App Information Display**: Shows app name, version, and build number
- 📄 **License Viewer**: Integrated license page access
- 🌐 **Multi-language Support**: Supports 7 languages (English, Japanese, Spanish, Korean, Portuguese, Turkish, Chinese)
- ⚡ **Riverpod Integration**: Built with Flutter Riverpod for efficient state management
- 🎨 **Customizable UI**: Simple ListTile with alert dialog for detailed information
- 📦 **Easy Integration**: Drop-in widget ready to use

## Supported Languages

- 🇺🇸 English (en-US)
- 🇯🇵 Japanese (ja-JP)
- 🇪🇸 Spanish (es-ES)
- 🇰🇷 Korean (ko-KR)
- 🇵🇹 Portuguese (pt-PT)
- 🇹🇷 Turkish (tr-TR)
- 🇨🇳 Chinese (zh-CN)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  app_info_tile: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Usage

### Basic Usage

```dart
import 'package:app_info_tile/app_info_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        children: [
          // Other settings tiles...
          AppInfoTile(), // Add the app info tile
        ],
      ),
    );
  }
}
```

### Setup with Easy Localization

This package requires `easy_localization` to be set up in your app:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: [
        Locale('en', 'US'),
        Locale('ja', 'JP'),
        Locale('es', 'ES'),
        Locale('ko', 'KR'),
        Locale('pt', 'PT'),
        Locale('tr', 'TR'),
        Locale('zh', 'CN'),
      ],
      path: 'assets/translations', // Path to your translation files
      fallbackLocale: Locale('en', 'US'),
      child: ProviderScope(
        child: MyApp(),
      ),
    ),
  );
}
```

### Required Dependencies

Make sure your `pubspec.yaml` includes these dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  easy_localization: ^3.0.7
  package_info_plus: ^8.0.0
  app_lang_selector: ^0.0.3
  riverpod_helper: ^0.0.3
```

## What it does

1. **Displays App Info**: The widget shows as a ListTile with an info icon and "About" title
2. **Opens Dialog**: Tapping the tile opens a dialog showing:
   - App name
   - Version and build number
   - License information hint
3. **License Viewer**: The dialog includes a button to open Flutter's built-in license page
4. **Multi-language**: All text is automatically localized based on your app's locale

## Customization

The package provides a clean, ready-to-use widget. For advanced customization, you can:

- Modify the provided localization files
- Use the underlying `AppInfoPod` provider directly for custom UI implementations
- Extend the widget by wrapping it in custom containers or adding additional styling

## Dependencies

This package relies on several well-maintained Flutter packages:

- `package_info_plus`: For accessing app package information
- `easy_localization`: For internationalization support
- `flutter_riverpod`: For state management
- `app_lang_selector`: For language selection functionality
- `riverpod_helper`: For enhanced Riverpod utilities

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you find this package helpful, please consider:

- ⭐ Starring the repository
- 🐛 Reporting issues
- 💝 [Sponsoring the developer](https://github.com/sponsors/normidar)
- 🐦 Following [@normidar](https://twitter.com/normidar) on Twitter
