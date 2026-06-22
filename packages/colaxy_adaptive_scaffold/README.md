# colaxy_adaptive_scaffold

[![GitHub](https://img.shields.io/github/license/normidar/colaxy_adaptive_scaffold.svg)](https://github.com/normidar/colaxy_adaptive_scaffold/blob/main/LICENSE)
[![pub package](https://img.shields.io/pub/v/colaxy_adaptive_scaffold.svg)](https://pub.dartlang.org/packages/colaxy_adaptive_scaffold)
[![GitHub Stars](https://img.shields.io/github/stars/normidar/colaxy_adaptive_scaffold.svg)](https://github.com/normidar/colaxy_adaptive_scaffold/stargazers)
[![Twitter](https://img.shields.io/twitter/url/https/twitter.com/normidar.svg?style=social&label=Follow%20%40normidar)](https://twitter.com/normidar)
[![Github-sponsors](https://img.shields.io/badge/sponsor-30363D?logo=GitHub-Sponsors&logoColor=#EA4AAA)](https://github.com/sponsors/normidar)

An adaptive scaffold that automatically switches between `NavigationBar` (bottom) and `NavigationRail` (side) based on screen aspect ratio.

## Features

- **Aspect Ratio-Based Adaptation**: Automatically switches navigation layout based on screen aspect ratio (width/height)
- **Smart Navigation for Many Items**: Automatically uses a Drawer menu on mobile when you have more than 4 navigation items
- **Simple API**: Just provide a list of navigation items with names, icons, and pages
- **Internal State Management**: No need to manage selected index yourself
- **Customizable Threshold**: Configure when the layout switch happens
- **Fully Documented**: Comprehensive parameter documentation and examples

## Getting Started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  colaxy_adaptive_scaffold:
    git:
      url: https://github.com/normidar/colaxy_adaptive_scaffold.git
```

## Usage

### Basic Example

```dart
import 'package:flutter/material.dart';
import 'package:colaxy_adaptive_scaffold/colaxy_adaptive_scaffold.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AdaptiveScaffold(
        items: [
          NavigationItem(
            name: 'Home',
            icon: Icon(Icons.home),
            page: HomePage(),
          ),
          NavigationItem(
            name: 'Search',
            icon: Icon(Icons.search),
            page: SearchPage(),
          ),
          NavigationItem(
            name: 'Settings',
            icon: Icon(Icons.settings),
            page: SettingsPage(),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Home Page'));
  }
}

class SearchPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Search Page'));
  }
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Settings Page'));
  }
}
```

### Advanced Example with Custom Settings

```dart
AdaptiveScaffold(
  items: [
    NavigationItem(
      name: 'Dashboard',
      icon: Icon(Icons.dashboard),
      page: DashboardPage(),
    ),
    NavigationItem(
      name: 'Analytics',
      icon: Icon(Icons.analytics),
      page: AnalyticsPage(),
    ),
  ],
  initialIndex: 0,                    // Start with first item selected
  aspectRatioThreshold: 1.5,          // Use side navigation only on wider screens
  floatingActionButton: FloatingActionButton(
    onPressed: () {},
    child: Icon(Icons.add),
  ),
)
```

## API Reference

### AdaptiveScaffold

The main widget that provides adaptive navigation.

#### Parameters

##### Required Parameters

- **`items`** (`List<NavigationItem>`): List of navigation items to display. Each item contains:
  - `name`: Label text for the navigation item
  - `icon`: Icon widget to display
  - `page`: Page widget to show when selected

##### Optional Parameters

- **`initialIndex`** (`int`, default: `0`): The initially selected navigation item index

- **`aspectRatioThreshold`** (`double`, default: `1.2`): The aspect ratio threshold for switching layouts
  - If `width/height >= threshold`: Uses `NavigationRail` (side navigation)
  - If `width/height < threshold`: Uses `NavigationBar` (bottom navigation)
  - Common values:
    - `1.0`: Switch at square screens
    - `1.2`: Switch at slightly landscape screens (default)
    - `1.5`: Switch only at wider landscape screens

- **`heightThresholdForLabels`** (`double`, default: `600`): Height threshold for showing labels in portrait mode
  - When in portrait mode and screen height is below this threshold, navigation labels are hidden to save space
  - Set to `0` to always show labels, or a very high value to always hide labels

- **`maxBottomNavigationItems`** (`int`, default: `4`): Maximum number of items to show in bottom navigation
  - In portrait mode, if the number of items exceeds this value, a Drawer menu is used instead
  - Prevents overcrowding in bottom navigation on mobile devices
  - The drawer can be opened via a menu button in the app bar

- **`floatingActionButton`** (`Widget?`): Optional floating action button to display

### NavigationItem

A class that defines a navigation destination.

#### Parameters

- **`name`** (`String`): The label text for this navigation item
- **`icon`** (`Widget`): The icon widget to display (typically an `Icon`)
- **`page`** (`Widget`): The page widget to display when this item is selected

## How It Works

The `AdaptiveScaffold` adapts its navigation UI based on screen dimensions and the number of navigation items:

### Layout Selection

1. **Landscape/Wide layouts** (aspect ratio >= threshold): Shows `NavigationRail` on the left side
2. **Portrait layouts with many items** (aspect ratio < threshold AND items > maxBottomNavigationItems): Shows `Drawer` menu accessible via app bar
3. **Portrait layouts with few items** (aspect ratio < threshold AND items <= maxBottomNavigationItems): Shows `NavigationBar` at the bottom

### Drawer Menu

When you have more than 4 navigation items (configurable via `maxBottomNavigationItems`) in portrait mode:
- A hamburger menu button appears in the top-left corner
- Tap it to open a drawer from the left side
- All navigation items are displayed in the drawer menu
- This prevents overcrowding in bottom navigation on mobile devices

This ensures optimal navigation placement based on the available screen space and the number of navigation items.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
