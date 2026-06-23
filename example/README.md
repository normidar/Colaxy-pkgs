# example

An example for Colaxy packages

## Overview

This project uses Riverpod for state management. Screenshots are captured based on Riverpod state and automatically fed into Fastlane.
Language, theme, and layout are all switched automatically. By looking at this example project, you can see how much the Colaxy project simplifies development for developers.

## We use riverpod to manage status

1. Add riverpod libraries:

```bash
dart pub add riverpod_helper riverpod_annotation flutter_riverpod dev:riverpod_generator dev:build_runner dev:custom_lint dev:riverpod_lint
```

> Recommended UI convention: put the rules in `ui/pages/`. Inside the `ui/pages` folder, always write a mock for each screen, and make sure each mock can render the screen without requiring any external data.

## How to support multiple languages?

1. Add libraries:

```bash
dart pub add easy_localization app_lang_selector
```

## A beautiful icon is good for your app.

We use the colaxy_icons_launcher library to generate icons. We are planning to fork it and use pure_svg, so SVG-format images can also be generated as icons.

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


