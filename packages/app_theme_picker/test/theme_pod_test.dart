import 'package:app_theme_picker/app_theme_picker.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ThemePod', () {
    test('falls back to defaultFlexScheme when nothing is stored', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(themePodProvider.future),
        defaultFlexScheme,
      );
    });

    test('restores the stored scheme', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.app_theme_picker:theme': FlexScheme.blue.index,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(themePodProvider.future), FlexScheme.blue);
    });

    test('ignores an index outside the current FlexScheme list', () async {
      // A value written by a version of flex_color_scheme with a different
      // scheme list must not blow up `FlexScheme.values[index]`.
      SharedPreferences.setMockInitialValues({
        'flutter.app_theme_picker:theme': 99999,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(themePodProvider.future),
        defaultFlexScheme,
      );
    });

    test('changeTheme persists and updates the state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(themePodProvider.future);

      await container
          .read(themePodProvider.notifier)
          .changeTheme(FlexScheme.mango);

      expect(container.read(themePodProvider).value, FlexScheme.mango);

      // A fresh container reads it back from storage.
      final reopened = ProviderContainer();
      addTearDown(reopened.dispose);
      expect(await reopened.read(themePodProvider.future), FlexScheme.mango);
    });
  });

  group('ThemeModePod', () {
    test('defaults to system rather than forcing light', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(themeModePodProvider.future),
        ThemeMode.system,
      );
    });

    test('restores the stored mode', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.app_theme_picker:theme_mode': 'dark',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(themeModePodProvider.future),
        ThemeMode.dark,
      );
    });

    test('falls back to system for an unrecognised stored value', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.app_theme_picker:theme_mode': 'not-a-mode',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(themeModePodProvider.future),
        ThemeMode.system,
      );
    });
  });

  group('overrides', () {
    test('themeOverride pins the scheme', () async {
      final container = ProviderContainer(
        overrides: [themeOverride(FlexScheme.sakura)],
      );
      addTearDown(container.dispose);

      expect(await container.read(themePodProvider.future), FlexScheme.sakura);
    });

    test('themeModeOverride pins the mode', () async {
      final container = ProviderContainer(
        overrides: [themeModeOverride(ThemeMode.dark)],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(themeModePodProvider.future),
        ThemeMode.dark,
      );
    });
  });
}
