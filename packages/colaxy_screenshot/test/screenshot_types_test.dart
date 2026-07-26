import 'package:colaxy_screenshot/colaxy_screenshot.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenshotModeInfo', () {
    test('phone uses the iPhone canvas size', () {
      expect(ScreenshotModeInfo.phone.mode, ScreenshotMode.phone);
      expect(ScreenshotModeInfo.phone.deviceSize, const Size(1284, 2778));
    });

    test('tablet uses the iPad canvas size', () {
      expect(ScreenshotModeInfo.tablet.mode, ScreenshotMode.tablet);
      expect(ScreenshotModeInfo.tablet.deviceSize, const Size(2048, 2732));
    });

    test('macos uses the desktop canvas size', () {
      expect(ScreenshotModeInfo.macos.mode, ScreenshotMode.macos);
      expect(ScreenshotModeInfo.macos.deviceSize, const Size(2560, 1600));
    });

    test('all contains phone and tablet only', () {
      expect(
        ScreenshotModeInfo.all.map((info) => info.mode),
        [ScreenshotMode.phone, ScreenshotMode.tablet],
      );
    });

    test('toDeviceInfo builds an iOS phone frame for phone mode', () {
      final info = ScreenshotModeInfo.phone.toDeviceInfo();
      expect(info.identifier.platform, TargetPlatform.iOS);
      expect(info.name, 'iPhone 14 Pro');
    });

    test('toDeviceInfo builds an iOS tablet frame for tablet mode', () {
      final info = ScreenshotModeInfo.tablet.toDeviceInfo();
      expect(info.identifier.platform, TargetPlatform.iOS);
      expect(info.name, 'iPad Pro 11"');
    });

    test('toDeviceInfo throws for macos mode', () {
      expect(
        ScreenshotModeInfo.macos.toDeviceInfo,
        throwsUnsupportedError,
      );
    });
  });

  group('ScreenshotConfig', () {
    ScreenshotConfig buildConfig() {
      return ScreenshotConfig(
        featureGraphicPage: const SizedBox(),
        supportedLocales: const [Locale('en', 'US')],
        pages: const [],
        wrapFunction: (child) => child,
        overrides: const [],
        easyLocalizationWrapper: (child) => EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/localizations',
          child: child,
        ),
      );
    }

    test('applies the documented defaults', () {
      final config = buildConfig();
      expect(config.captureDelay, const Duration(milliseconds: 500));
      expect(config.backgroundColor, const Color(0xFF1E1E1E));
      expect(config.titleStyle, isNull);
      expect(config.enableIos, isTrue);
      expect(config.enableAndroid, isTrue);
      expect(config.enableMacos, isFalse);
    });

    test('wrapFunction wraps the given widget', () {
      final config = buildConfig();
      const child = Text('page');
      expect(config.wrapFunction(child), same(child));
    });
  });

  group('ScreenshotPageInfo', () {
    test('holds the given values', () {
      const page = ScreenshotPageInfo(
        name: 'home',
        index: 0,
        widget: SizedBox.new,
        titleTextKey: 'home_title',
      );

      expect(page.name, 'home');
      expect(page.index, 0);
      expect(page.titleTextKey, 'home_title');
      expect(page.overrides, isNull);
      expect(page.titleStyle, isNull);
      expect(page.backgroundColor, isNull);
      expect(page.widget(), isA<SizedBox>());
    });
  });
}
