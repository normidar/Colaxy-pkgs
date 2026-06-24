# example

An example for Colaxy packages

## Overview

This project uses Riverpod for state management. Screenshots are captured based on Riverpod state and automatically fed into Fastlane.
Language, theme, and layout are all switched automatically. By looking at this example project, you can see how much the Colaxy project simplifies development for developers.

> If you use this example, you can run this first: `flutter create --platform=android,ios,linux,macos,web,windows .`

## We use riverpod to manage status

1. Add riverpod libraries:

```bash
dart pub add riverpod_helper riverpod_annotation flutter_riverpod dev:riverpod_generator dev:build_runner dev:custom_lint dev:riverpod_lint
```

> Recommended UI convention: put the rules in `ui/pages/`. Inside the `ui/pages` folder, always write a mock for each screen, and make sure each mock can render the screen without requiring any external data.

## How to support multiple languages?

1. Add libraries:

```bash
dart pub add easy_localization app_lang_selector dev:colaxy_localization
```

Here is what each library does:

- `easy_localization` -> Automatically loads and displays your app's translated resources, using a syntax like `'your_context_key'.tr()`.
- `app_lang_selector` -> Provides UI for letting users switch the app's language at runtime.
- `dev:colaxy_localization` -> Manages the resources used by Fastlane and by `easy_localization` from a single, unified source.

2. Initialize `easy_localization`

Add the initialization code as shown below:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  ...
}
```

3. Wrap your app with `EasyLocalization` and add `assets/localizations/{locale}.json` files for each locale you want to support:

```dart
EasyLocalization languageWidgetWrapper(Widget widget) {
  return EasyLocalization(
    supportedLocales: const [
      Locale('ja', 'JP'),
      Locale('en', 'US'),
      Locale('zh', 'CN'),
    ],
    path: 'assets/localizations',
    fallbackLocale: const Locale('en', 'US'),
    child: widget,
  );
}
```

4. Run `colaxy_localization` to generate the Android/iOS native localization files and the Fastlane metadata from your `assets/localizations/*.json` files:

```bash
dart run colaxy_localization:gen
```

## A beautiful icon is good for your app.

We use the `colaxy_icons_launcher` library to generate icons. It is a fork of [icons_launcher](https://github.com/mrrhak/icons_launcher) with added support for SVG-format images, so you can generate icons directly from an SVG source instead of a raster image.

SVG files are recommended because they are essentially text-based, which keeps your repository lightweight and your icon easy to tweak. Try to keep the SVG as simple and original as possible.

1. Add the library:

```bash
dart pub add dev:colaxy_icons_launcher
```

2. Configure `flutter_icons` in your `pubspec.yaml`, pointing `image_path` to your SVG file:

```yaml
colaxy_icons_launcher:
  image_path: 'assets/icon.svg'
  platforms:
    android:
      enable: true
    ios:
      enable: true
    web:
      enable: true
    macos:
      enable: true
    windows:
      enable: true
    linux:
      enable: true
```

3. Generate the icons:

```bash
dart run colaxy_icons_launcher:create
```

## Will you release your app to a store? Use Fastlane!

Check out the Fastlane homepage and install Fastlane!

First,

...(assuming macOS)

## How to take screenshots automatically?

> Precondition: Ensure that your project is already set up with Fastlane and app_lang_selector.

1. Create a config.json file at `your_project/assets/config.json`
2. Add content like this (app_path must be an absolute path):

```json
{
  "launch_mode": "screenshot",
  "app_path": "/your/app/path/your_project"
}
```

3. In your route code

```dart
  ...
  if (await checkScreenshotRunable()) {
    await screenshotMain(widgetWrapper);
  } else {
    await normalMain(widgetWrapper);
  }
  ...
```


