import 'package:app_theme_picker/app_theme_picker.dart' as atp;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_shell.dart';

/// Root widget. Reads the light/dark [ThemeData] and [ThemeMode] that
/// `app_theme_picker` persists via SharedPreferences, and rebuilds
/// [MaterialApp] whenever the user changes them from the Settings tab.
class ExampleApp extends ConsumerWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lightTheme = ref.watch(atp.lightThemeDataProvider());
    final darkTheme = ref.watch(atp.darkThemeDataProvider());
    final themeMode = ref.watch(atp.themeModePodProvider);

    return MaterialApp(
      title: 'app_title'.tr(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: lightTheme.value,
      darkTheme: darkTheme.value,
      themeMode: themeMode.value ?? ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
