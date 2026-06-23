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

## How to support multiple languages?

1. Add libraries:

```bash
dart pub add easy_localization app_lang_selector
```

## Will you release your app to store? use Fastlane!



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


