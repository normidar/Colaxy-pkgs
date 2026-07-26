import 'package:app_theme_picker/app_theme_picker.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const prefKey = 'app_theme_picker:theme';

  late ProviderContainer container;

  ProviderContainer newContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = newContainer();
  });

  group('ThemePod', () {
    test('defaults to sakura when nothing is stored', () async {
      expect(
        await container.read(themePodProvider.future),
        FlexScheme.sakura,
      );
    });

    test('restores the stored scheme index', () async {
      SharedPreferences.setMockInitialValues({
        prefKey: FlexScheme.mandyRed.index,
      });
      expect(
        await container.read(themePodProvider.future),
        FlexScheme.mandyRed,
      );
    });

    test('falls back to sakura for an out-of-range stored index', () async {
      SharedPreferences.setMockInitialValues({
        prefKey: FlexScheme.values.length + 100,
      });
      expect(
        await container.read(themePodProvider.future),
        FlexScheme.sakura,
      );
    });

    test('falls back to sakura for a negative stored index', () async {
      SharedPreferences.setMockInitialValues({prefKey: -1});
      expect(
        await container.read(themePodProvider.future),
        FlexScheme.sakura,
      );
    });

    test('changeTheme updates the state', () async {
      await container.read(themePodProvider.future);
      await container
          .read(themePodProvider.notifier)
          .changeTheme(FlexScheme.gold);
      expect(
        container.read(themePodProvider).value,
        FlexScheme.gold,
      );
    });

    test('changeTheme persists across containers', () async {
      await container.read(themePodProvider.future);
      await container
          .read(themePodProvider.notifier)
          .changeTheme(FlexScheme.jungle);

      final freshContainer = newContainer();
      expect(
        await freshContainer.read(themePodProvider.future),
        FlexScheme.jungle,
      );
    });
  });

  group('ThemeModePod', () {
    const modeKey = 'app_theme_picker:theme_mode';

    test('defaults to light when nothing is stored', () async {
      expect(
        await container.read(themeModePodProvider.future),
        ThemeMode.light,
      );
    });

    test('restores the stored mode', () async {
      SharedPreferences.setMockInitialValues({modeKey: 'dark'});
      expect(
        await container.read(themeModePodProvider.future),
        ThemeMode.dark,
      );
    });

    test('falls back to light for an unknown stored value', () async {
      SharedPreferences.setMockInitialValues({modeKey: 'not_a_mode'});
      expect(
        await container.read(themeModePodProvider.future),
        ThemeMode.light,
      );
    });

    test('changeThemeMode updates the state and persists', () async {
      await container.read(themeModePodProvider.future);
      await container
          .read(themeModePodProvider.notifier)
          .changeThemeMode(ThemeMode.system);
      expect(
        container.read(themeModePodProvider).value,
        ThemeMode.system,
      );

      final freshContainer = newContainer();
      expect(
        await freshContainer.read(themeModePodProvider.future),
        ThemeMode.system,
      );
    });
  });

  group('theme data providers', () {
    test('lightThemeData builds a light theme from the scheme', () async {
      final theme = await container.read(lightThemeDataProvider().future);
      expect(theme.brightness, Brightness.light);
    });

    test('darkThemeData builds a dark theme from the scheme', () async {
      final theme = await container.read(darkThemeDataProvider().future);
      expect(theme.brightness, Brightness.dark);
    });

    test('font family is applied when given', () async {
      final theme =
          await container.read(lightThemeDataProvider('Roboto').future);
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Roboto');
    });
  });

  group('mocks', () {
    test('theme mock overrides provide their scheme', () async {
      final mocked = ProviderContainer(overrides: [sakuraThemeOverride]);
      addTearDown(mocked.dispose);
      expect(
        await mocked.read(themePodProvider.future),
        FlexScheme.sakura,
      );

      final gold = ProviderContainer(
        overrides: [themePodProvider.overrideWith(GoldThemeMock.new)],
      );
      addTearDown(gold.dispose);
      expect(await gold.read(themePodProvider.future), FlexScheme.gold);
    });

    test('theme mode mock overrides provide their mode', () async {
      final dark = ProviderContainer(overrides: [darkThemeOverride]);
      addTearDown(dark.dispose);
      expect(await dark.read(themeModePodProvider.future), ThemeMode.dark);

      final light = ProviderContainer(overrides: [lightThemeOverride]);
      addTearDown(light.dispose);
      expect(await light.read(themeModePodProvider.future), ThemeMode.light);
    });
  });
}
