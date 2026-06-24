import 'package:app_info_tile/app_info_tile.dart' as ait;
import 'package:app_lang_selector/app_lang_selector.dart' as als;
import 'package:app_theme_picker/app_theme_picker.dart' as atp;
import 'package:colaxy_screenshot/colaxy_screenshot.dart';
import 'package:colaxy_tutorial/colaxy_tutorial.dart' as ct;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  EasyLocalization languageWidgetWrapper(Widget widget) {
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
      child: widget,
    );
  }

  if (await checkScreenshotRunable()) {
    // await screenshotMain(elw);
  } else {
    // await normalMain(elw);
  }
}