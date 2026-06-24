# Colaxy Tutorial

[![GitHub](https://img.shields.io/github/license/normidar/colaxy_tutorial.svg)](https://github.com/normidar/colaxy_tutorial/blob/main/LICENSE)
[![pub package](https://img.shields.io/pub/v/colaxy_tutorial.svg)](https://pub.dartlang.org/packages/colaxy_tutorial)
[![GitHub Stars](https://img.shields.io/github/stars/normidar/colaxy_tutorial.svg)](https://github.com/normidar/colaxy_tutorial/stargazers)
[![Twitter](https://img.shields.io/twitter/url/https/twitter.com/normidar2.svg?style=social&label=Follow%20%40normidar2)](https://twitter.com/normidar2)
[![Github-sponsors](https://img.shields.io/badge/sponsor-30363D?logo=GitHub-Sponsors&logoColor=#EA4AAA)](https://github.com/sponsors/normidar)

A powerful and flexible Flutter package for creating interactive tutorials, onboarding flows, and contextual hints in your Flutter applications. Built with version tracking capabilities and user preference management.

## Features

✨ **Interactive Tutorials**: Create step-by-step guided tutorials using coach marks  
🎯 **Contextual Hints**: Display targeted hints and tips to users  
📱 **Version Tracking**: Track app versions and show tutorials only to specific version users  
💾 **Persistent Storage**: Remember user preferences and tutorial completion status  
🎨 **Customizable UI**: Flexible styling options for tutorial content and appearance  
⚙️ **Settings Management**: Built-in settings page for tutorial management  
🌐 **Localization Ready**: Full support for internationalization with easy_localization  
🛡️ **Guarded Pages**: Protect pages with one-time tutorials  
📄 **Tutorial Pages**: Create multi-page tutorial flows with navigation

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  colaxy_tutorial: ^0.1.1
```

Run `flutter pub get` to install the package.

## Quick Start

### Basic Tutorial Setup

```dart
import 'package:colaxy_tutorial/colaxy_tutorial.dart';

// 1. Create tutorial data sets
final tutorialDataSets = [
  TutorialDataSet(
    id: 'welcome_tutorial',
    key: _welcomeKey, // GlobalKey for your widget
    align: TutorialAlign.bottom,
    shape: TutorialShape.circle,
    builder: (context) => Text('Welcome to our app!'),
  ),
];

// 2. Show the tutorial
await TutorialTool.showTutorial(
  dataSets: tutorialDataSets,
  buildContext: context,
);
```

### Dialog-Based Hints

```dart
await TutorialTool.showTutorialDialog(
  id: 'new_feature_hint',
  buildContext: context,
  title: 'New Feature',
  child: Text('Check out this amazing new feature!'),
  showDontShowAgain: true, // Show "Don't show again" option
);
```

### Tutorial Pages

```dart
await TutorialTool.jumpToTutorialPage(
  id: 'onboarding_tutorial',
  buildContext: context,
  pages: [
    _buildTutorialPage(
      context,
      icon: Icons.welcome,
      title: 'Welcome!',
      description: 'This is the first page of your tutorial.',
      color: Colors.blue.shade100,
    ),
    _buildTutorialPage(
      context,
      icon: Icons.star,
      title: 'Get Started',
      description: 'Learn how to use our amazing features.',
      color: Colors.green.shade100,
    ),
  ],
);
```

### Guarded Pages

```dart
// Navigate to a page that shows tutorial only once
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TutorialTool.guardTutorialPage(
      id: 'feature_tutorial',
      pages: [
        _buildTutorialPage(
          context,
          icon: Icons.lock,
          title: 'Protected Feature',
          description: 'This feature requires a tutorial first.',
          color: Colors.orange.shade100,
        ),
      ],
      nextPage: const ProtectedFeaturePage(),
    ),
  ),
);
```

## Core Components

### TutorialDataSet

The main configuration object for tutorial steps:

```dart
TutorialDataSet(
  id: 'unique_tutorial_id',           // Unique identifier
  key: GlobalKey(),                   // Target widget key
  align: TutorialAlign.bottom,        // Content alignment
  shape: TutorialShape.circle,        // Highlight shape
  builder: (context) => Widget(),     // Tutorial content builder
)
```

### TutorialAlign Options

- `TutorialAlign.top` - Content appears above the target
- `TutorialAlign.bottom` - Content appears below the target
- `TutorialAlign.left` - Content appears to the left
- `TutorialAlign.right` - Content appears to the right

### TutorialShape Options

- `TutorialShape.circle` - Circular highlight
- `TutorialShape.rRect` - Rounded rectangle highlight

## Version Tracking

Track app versions and show tutorials conditionally:

```dart
// Record current app version
await VersionRecorder.recordVersion();

// Check if user has used specific versions
bool hasUsedVersion = await VersionRecorder.isRecordedVersionOr(
  checker: (version) => version == '2.0.0',
);

// Check if user has used ALL specified versions
bool hasUsedAllVersions = await VersionRecorder.isRecordedVersionAnd(
  checker: (version) => ['1.0.0', '1.1.0'].contains(version),
);

// Show tutorial based on version history
if (hasUsedVersion) {
  await TutorialTool.showTutorialDialog(
    id: 'migration_help',
    buildContext: context,
    title: 'App Updated',
    child: Text('Here are the new changes...'),
    showDontShowAgain: true,
  );
}
```

## UI Components

### Tutorial Settings Page

Provide users with tutorial management options:

```dart
import 'package:colaxy_tutorial/colaxy_tutorial.dart';

// Navigate to built-in settings page
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => TutorialSettingsPage()),
);
```

### Tutorial Reset Tile

Add a settings tile to your app:

```dart
// In your settings list
TutorialResetTile(), // Automatically navigates to TutorialSettingsPage
```

## Advanced Usage

### Force Show Tutorials

```dart
// Reset specific tutorial to show again
await TutorialTool.resetTutorial();

// Or show dialog without "Don't show again" option
await TutorialTool.showTutorialDialog(
  id: 'important_update',
  buildContext: context,
  title: 'Important Update',
  child: Text('Critical information...'),
  showDontShowAgain: false, // No "Don't show again" option
);
```

### Reset All Tutorials

```dart
// Reset all tutorial completion status
await TutorialTool.resetTutorial();
```

### Tutorial Content Widget

Use the built-in `TutorialContent` widget for consistent styling:

```dart
TutorialDataSet(
  id: 'welcome_tutorial',
  key: _welcomeKey,
  align: TutorialAlign.bottom,
  shape: TutorialShape.circle,
  builder: (context) => const TutorialContent(
    title: 'Welcome!',
    description: 'This is a tutorial step with consistent styling.',
  ),
)
```

## Localization Support

The package uses `easy_localization` for internationalization. Add these keys to your translation files:

```json
{
  "colaxy_tutorial:skip": "Skip",
  "colaxy_tutorial:dont_show_again": "Don't show again",
  "colaxy_tutorial:understood": "Got it",
  "colaxy_tutorial:settings_page_title": "Tutorial Settings",
  "colaxy_tutorial:reset_tutorial": "Reset all tutorials",
  "colaxy_tutorial:reset": "Reset",
  "colaxy_tutorial:reset_successful": "Successfully reset",
  "colaxy_tutorial:ok": "OK",
  "colaxy_tutorial:start": "Start",
  "colaxy_tutorial:tile_title": "Tutorial Settings"
}
```

## Dependencies

This package depends on:

- `flutter`: SDK
- `tutorial_coach_mark`: ^1.2.12 - Core tutorial functionality
- `shared_preferences`: ^2.2.3 - Persistent storage
- `package_info_plus`: ^9.0.0 - App version information
- `easy_localization`: ^3.0.7 - Internationalization
- `flutter_riverpod`: ^2.6.1 - State management
- `app_lang_selector`: ^0.0.1 - Language selection

## Example

Check out the [example](example/) directory for a complete implementation demonstrating all features of the package.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you find this package helpful, please consider:

- ⭐ Starring the repository
- 🐛 Reporting bugs
- 💡 Suggesting new features
- 🤝 Contributing to the codebase

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed list of changes and updates.
