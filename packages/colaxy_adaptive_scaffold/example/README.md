# Adaptive Scaffold Example

This example demonstrates how to use the `colaxy_adaptive_scaffold` package.

## Features Demonstrated

- Creating an `AdaptiveScaffold` with multiple navigation items
- Automatic switching between bottom navigation (portrait) and side navigation (landscape)
- Custom aspect ratio threshold configuration
- Adding a floating action button

## Running the Example

```bash
cd example
flutter pub get
flutter run
```

## Try It Out

1. Run the app on a device or emulator
2. Rotate the device or resize the window to see the navigation adapt
3. The navigation will switch from bottom to side when the aspect ratio exceeds 1.2

## Code Structure

- `main.dart`: Contains the example app with `AdaptiveScaffold` setup
- Four sample pages: Home, Search, Profile, and Settings
