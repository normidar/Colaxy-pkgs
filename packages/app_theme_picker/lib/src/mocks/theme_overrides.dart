import 'package:app_theme_picker/app_theme_picker.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';

/// A [ThemePod] pinned to a fixed scheme, ignoring the persisted preference.
///
/// Useful in tests, widget previews and screenshot runs where the theme must be
/// deterministic.
class FixedThemePod extends ThemePod {
  /// Creates a pod that always resolves to [scheme].
  FixedThemePod(this.scheme);

  /// The scheme this pod always returns.
  final FlexScheme scheme;

  @override
  Future<FlexScheme> build() async => scheme;
}

/// A [ThemeModePod] pinned to a fixed mode, ignoring the persisted preference.
class FixedThemeModePod extends ThemeModePod {
  /// Creates a pod that always resolves to [mode].
  FixedThemeModePod(this.mode);

  /// The mode this pod always returns.
  final ThemeMode mode;

  @override
  Future<ThemeMode> build() async => mode;
}

/// A `ProviderScope` override pinning the colour scheme to [scheme].
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     themeOverride(FlexScheme.sakura),
///     themeModeOverride(ThemeMode.light),
///   ],
///   child: const MyApp(),
/// )
/// ```
///
/// This replaces the ~80 hand-written `<Name>ThemeMock` classes and matching
/// `<name>ThemeOverride` values that used to be shipped in `lib/`.
Override themeOverride(FlexScheme scheme) =>
    themePodProvider.overrideWith(() => FixedThemePod(scheme));

/// A `ProviderScope` override pinning the light/dark mode to [mode].
Override themeModeOverride(ThemeMode mode) =>
    themeModePodProvider.overrideWith(() => FixedThemeModePod(mode));
