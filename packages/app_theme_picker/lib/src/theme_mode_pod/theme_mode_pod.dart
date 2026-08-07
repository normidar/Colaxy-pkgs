import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod_helper/riverpod_helper.dart';

part 'theme_mode_pod.g.dart';

/// Called after [ThemeModePod.changeThemeMode] persists a new mode.
///
/// Assign this to observe theme mode changes (e.g. for analytics) without
/// depending on Riverpod: `onThemeModeChanged = (mode) => myLogger(mode);`
void Function(ThemeMode mode)? onThemeModeChanged;

@Riverpod(keepAlive: true)
class ThemeModePod extends _$ThemeModePod {
  final _key = 'app_theme_picker:theme_mode';

  @override
  Future<ThemeMode> build() async {
    final themeMode = await ref.read(prefsAliveStringPodProvider(_key).future);
    // Defaults to `system` so a fresh install follows the platform setting
    // instead of forcing light mode.
    if (themeMode != null) {
      return ThemeMode.values.firstWhere(
        (element) => element.name == themeMode,
        orElse: () => ThemeMode.system,
      );
    }
    return ThemeMode.system;
  }

  Future<void> changeThemeMode(ThemeMode themeMode) async {
    await ref
        .read(prefsAliveStringPodProvider(_key).notifier)
        .setValue(themeMode.name);
    state = AsyncData(themeMode);
    onThemeModeChanged?.call(themeMode);
  }
}
