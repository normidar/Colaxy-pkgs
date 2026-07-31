import 'dart:async';

import 'package:app_theme_picker/src/theme_color_button.dart';
import 'package:app_theme_picker/src/theme_mode_button.dart';
import 'package:app_theme_picker/src/theme_pod/theme_pod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_helper/riverpod_helper.dart';

// pick_theme_page

/// A page for picking the app's colour scheme and light/dark mode.
class PickThemePage extends ConsumerWidget {
  /// Creates the theme picker page.
  const PickThemePage({
    this.size = 70,
    this.availableSchemes,
    super.key,
  });

  /// When non-null, only these schemes are offered.
  ///
  /// Previously a `Set<String>` compared against `FlexScheme.name`, so a typo
  /// silently filtered everything out.
  final Set<FlexScheme>? availableSchemes;

  /// Size of each colour swatch.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themePodProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor.withAlpha(100),
        // The AppBar only ever gets a plain title: rendering the scrollable
        // RiverpodErrorView here used to break the layout. The error itself is
        // reported in the body below.
        title: Text(
          switch (theme) {
            AsyncData(:final value) =>
              '${value.name} ${'app_theme_picker:theme'.tr()}',
            _ => 'app_theme_picker:theme'.tr(),
          },
        ),
      ),
      body: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: switch (theme) {
                AsyncData(:final value) => Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 5,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ThemeModeButton(mode: ThemeMode.light),
                          ThemeModeButton(mode: ThemeMode.system),
                          ThemeModeButton(mode: ThemeMode.dark),
                        ],
                      ),
                    ),
                    ...FlexColor.schemes.entries
                        .where(
                          (m) => availableSchemes?.contains(m.key) ?? true,
                        )
                        .map(
                          (data) => ThemeColorButton(
                            schemeData: data.value,
                            onTap: () => unawaited(
                              ref
                                  .read(themePodProvider.notifier)
                                  .changeTheme(data.key),
                            ),
                            size: size,
                            selected: value == data.key,
                          ),
                        ),
                  ],
                ),
                AsyncLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                AsyncError(:final error, :final stackTrace) =>
                  RiverpodErrorView(
                    widgetName: '$PickThemePage',
                    error: error,
                    stackTrace: stackTrace,
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}
