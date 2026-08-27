import 'package:app_info_tile/app_info_tile.dart' as ait;
import 'package:app_lang_selector/app_lang_selector.dart' as als;
import 'package:app_theme_picker/app_theme_picker.dart' as atp;
import 'package:colaxy_screenshot/colaxy_screenshot.dart';
import 'package:colaxy_tutorial/colaxy_tutorial.dart' as ct;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/example_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (await checkScreenshotRunable()) {
    // Hook up colaxy_screenshot's `takeScreenshots(...)` here to generate
    // App Store / Play Store assets.
    return;
  }

  runApp(const ProviderScope(child: _Localized(child: ExampleApp())));
}

/// Wires up easy_localization with [als.PkgsAssetLoader] so the strings bundled
/// with each colaxy package are merged into the app's own translations.
class _Localized extends StatelessWidget {
  const _Localized({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return EasyLocalization(
      supportedLocales: const [
        Locale('ja', 'JP'),
        Locale('en', 'US'),
        Locale('zh', 'CN'),
        Locale('tr', 'TR'),
        Locale('pt', 'PT'),
        Locale('es', 'ES'),
      ],
      path: 'assets/localizations',
      assetLoader: const als.PkgsAssetLoader(
        packages: [
          als.packageName,
          atp.packageName,
          ait.packageName,
          ct.packageName,
        ],
      ),
      fallbackLocale: const Locale('en', 'US'),
      child: child,
    );
  }
}
