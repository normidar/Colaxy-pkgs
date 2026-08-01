# colaxy_screenshot

[![GitHub](https://img.shields.io/github/license/normidar/colaxy_screenshot.svg)](https://github.com/normidar/colaxy_screenshot/blob/main/LICENSE)
[![pub package](https://img.shields.io/pub/v/colaxy_screenshot.svg)](https://pub.dartlang.org/packages/colaxy_screenshot)
[![GitHub Stars](https://img.shields.io/github/stars/normidar/colaxy_screenshot.svg)](https://github.com/normidar/colaxy_screenshot/stargazers)
[![Twitter](https://img.shields.io/twitter/url/https/twitter.com/normidar.svg?style=social&label=Follow%20%40normidar)](https://twitter.com/normidar2)
[![Github-sponsors](https://img.shields.io/badge/sponsor-30363D?logo=GitHub-Sponsors&logoColor=#EA4AAA)](https://github.com/sponsors/normidar)

A powerful Flutter package for automated screenshot generation for App Store, Google Play Store, and Mac App Store listings. Generate beautiful, consistent screenshots across multiple devices, languages, and platforms with ease.

## Features

✨ **Multi-platform Support**: Generate screenshots for iOS, Android, and macOS  
🌍 **Multi-language Support**: Support for Japanese, English, Chinese, and more  
📱 **Device Compatibility**: Phone, tablet, and macOS screenshot generation  
🎨 **Marketing Layouts**: Beautiful backgrounds and titles for app store listings  
🚀 **Fastlane Integration**: Direct integration with Fastlane for automated app store uploads  
⚙️ **Highly Configurable**: Customizable layouts, delays, and overrides  
🎯 **Device Frame Support**: Realistic device frames using device_frame_plus

## Installation

Run the following command:

```sh
flutter pub add colaxy_screenshot
```

## Setup

### 1. Add Configuration File

Create `assets/config.json` in your project:

```json
{
  "app_path": "/path/to/your/app",
  "launch_mode": "screenshot"
}
```

### 2. Add Translation Files

Create translation files in `assets/translations/`:

- `assets/translations/en.json`
- `assets/translations/ja.json`
- `assets/translations/zh.json`

Example `en.json`:

```json
{
  "welcome_title": "Welcome to Our App",
  "features_title": "Amazing Features",
  "settings_title": "Customize Your Experience"
}
```

### 3. Update pubspec.yaml

```yaml
flutter:
  assets:
    - assets/config.json
    - assets/translations/
```

## Usage

### Basic Setup

```dart
import 'package:colaxy_screenshot/colaxy_screenshot.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (await checkScreenshotRunable()) {
    await takeScreenshots(ScreenshotConfig(
      featureGraphicPage: const MyFeatureGraphicPage(),
      easyLocalizationWrapper: (child) => EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ja')],
        path: 'assets/translations',
        child: child,
      ),
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ja', 'JP'),
      ],
      pages: [
        ScreenshotPageInfo(
          name: 'welcome',
          index: 1,
          titleTextKey: 'welcome_title',
          widget: () => const WelcomeScreen(),
        ),
        ScreenshotPageInfo(
          name: 'features',
          index: 2,
          titleTextKey: 'features_title',
          widget: () => const FeaturesScreen(),
        ),
      ],
      wrapFunction: (child) => MaterialApp(
        home: child,
        theme: ThemeData.light(),
      ),
      overrides: [], // Riverpod overrides if needed
    ));
    return;
  }

  runApp(const MyApp());
}
```

### Enabling macOS Screenshots

Set `enableMacos: true` to also generate Mac App Store screenshots (2560×1600):

```dart
ScreenshotConfig(
  // ... other config
  enableMacos: true,
)
```

macOS screenshots are saved alongside iOS screenshots under `fastlane/screenshots/` using Fastlane's macOS naming convention.

### Advanced Configuration

```dart
ScreenshotConfig(
  // ... basic config
  captureDelay: const Duration(milliseconds: 1000),
  backgroundColor: const Color(0xFF1E1E1E),
  titleStyle: const TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.bold,
    color: Colors.blue,
  ),
  enableMacos: true,
)
```

### Page Configuration with Overrides

```dart
ScreenshotPageInfo(
  name: 'profile',
  index: 3,
  titleTextKey: 'profile_title',
  widget: () => const ProfileScreen(),
  overrides: [
    userProvider.overrideWith((ref) => mockUser),
  ],
  backgroundColor: Colors.purple,
  titleStyle: const TextStyle(color: Colors.white),
)
```

## Output Structure

Screenshots are automatically organized for Fastlane:

```
your_app/
├── fastlane/
│   ├── screenshots/
│   │   ├── en-US/
│   │   │   ├── 1_iphone65_1.welcome.png
│   │   │   ├── 1_ipadPro13_1.welcome.png
│   │   │   └── 1_mac_1.welcome.png        # enableMacos: true のみ
│   │   ├── ja/
│   │   └── zh-Hans/
│   └── metadata/
│       └── android/
│           ├── featureGraphic.png
│           ├── en-US/images/phoneScreenshots/
│           ├── ja-JP/images/phoneScreenshots/
│           └── zh-CN/images/phoneScreenshots/
```

## Supported Devices

### Phone Screenshots

- **iOS**: iPhone 13 (1284×2778)
- **Android**: Phone screenshots (1284×2778), 7-inch screenshots (1284×2778)

### Tablet Screenshots

- **iOS**: iPad Pro 13" (2064×2752)
- **Android**: 10-inch tablet screenshots (2064×2752)

### macOS Screenshots (`enableMacos: true`)

- **Mac**: 2560×1600 (Retina)

## Configuration Options

| Parameter                  | Type                     | Required | Description                                      |
| -------------------------- | ------------------------ | :------: | ------------------------------------------------ |
| `featureGraphicPage`       | Widget                   | ✓        | Widget used for the Android feature graphic      |
| `supportedLocales`         | List\<Locale\>           | ✓        | Languages to generate screenshots for            |
| `pages`                    | List\<ScreenshotPageInfo\> | ✓      | Pages to screenshot                              |
| `wrapFunction`             | Widget Function(Widget)  | ✓        | Wrapper function for your app (e.g. MaterialApp) |
| `overrides`                | List\<Override\>         | ✓        | Global Riverpod overrides                        |
| `easyLocalizationWrapper`  | EasyLocalizationWrapper  | ✓        | EasyLocalization setup function                  |
| `captureDelay`             | Duration                 |          | Delay between screenshots (default: 500ms)       |
| `backgroundColor`          | Color                    |          | Background color (default: dark gray)            |
| `titleStyle`               | TextStyle?               |          | Global title text style                          |
| `enableMacos`              | bool                     |          | Generate macOS screenshots (default: `false`)    |

## Requirements

- **Platform**: macOS only (for development)
- **Mode**: Debug mode only
- **Flutter**: >=1.17.0
- **Dart**: ^3.0.0

## Dependencies

This package relies on several key Flutter packages:

- `device_frame_plus`: For realistic device frames
- `easy_localization`: For internationalization
- `flutter_riverpod`: For state management
- `image`: For image processing
- `window_size`: For controlling the window dimensions during capture

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you find this package helpful, consider:

- Starring the repository
- Reporting issues
- Suggesting new features
- [Sponsoring the developer](https://github.com/sponsors/normidar)
