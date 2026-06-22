# App Lang Selector Example

This is a sample Flutter application demonstrating how to use the `app_lang_selector` package.

## Features

- Language selection UI with native language names
- Easy integration with `easy_localization`
- State management with Riverpod
- Support for multiple languages including:
  - English
  - Japanese (日本語)
  - Chinese (简体中文)
  - Korean (한국어)
  - Spanish (Español)
  - French (Français)
  - German (Deutsch)
  - Italian (Italiano)
  - Portuguese (Português)
  - Russian (Русский)
  - Vietnamese (Tiếng Việt)
  - Arabic (العربية)

## Running the Example

1. Ensure you have Flutter installed and configured
2. Navigate to the example directory:
   ```bash
   cd example
   ```
3. Get dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## How it Works

The example app demonstrates:

1. **Language Selection Tile**: A simple ListTile that opens the language selection page
2. **Language Selection Page**: A full-screen page showing all available languages
3. **State Persistence**: Selected language is maintained across app sessions
4. **System Language Support**: Option to follow the system language setting

## Code Structure

- `lib/main.dart`: Main application setup with EasyLocalization and Riverpod
- `assets/localizations/`: Translation files for all supported languages

## Integration

The example shows how easy it is to integrate `app_lang_selector` into your Flutter app:

```dart
// Add the language selection tile to your settings
const AppLangSelectTile()

// Or navigate directly to the language selection page
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const AppLangSelectPage(),
  ),
);
```
