import 'package:colaxy_screenshot/colaxy_screenshot.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ScreenshotConfig _config({
  List<Locale> locales = const [Locale('en', 'US')],
  bool enableIos = true,
  bool enableAndroid = true,
  bool enableMacos = false,
}) {
  return ScreenshotConfig(
    featureGraphicPage: const SizedBox.shrink(),
    supportedLocales: locales,
    pages: [
      ScreenshotPageInfo(
        name: 'home',
        index: 0,
        widget: () => const SizedBox.shrink(),
        titleTextKey: 'home_title',
      ),
    ],
    wrapFunction: (w) => w,
    overrides: const [],
    easyLocalizationWrapper: (w) => EasyLocalization(
      supportedLocales: locales,
      path: 'assets/localizations',
      child: w,
    ),
    enableIos: enableIos,
    enableAndroid: enableAndroid,
    enableMacos: enableMacos,
  );
}

void main() {
  group('ScreenshotConfig defaults', () {
    test('the first capture waits longer than the rest', () {
      final config = _config();
      expect(config.firstCaptureDelay, greaterThan(config.captureDelay));
    });

    test('styling defaults are the values that used to be hardcoded', () {
      final config = _config();
      expect(config.backgroundColor, kDefaultScreenshotBackgroundColor);
      // `titleStyle` stays null so a per-page style can win; the service falls
      // back to kDefaultScreenshotTitleStyle.
      expect(config.titleStyle, isNull);
      expect(kDefaultScreenshotTitleStyle.fontSize, 48);
    });

    test('the feature graphic icon path is configurable', () {
      expect(_config().featureGraphicIconAsset, 'assets/app_icons/icon.png');
    });
  });

  group('locale validation', () {
    test('accepts every mapped locale', () {
      final service = ScreenshotService(
        config: _config(
          locales: const [
            Locale('en', 'US'),
            Locale('ja', 'JP'),
            Locale('zh', 'CN'),
          ],
        ),
        appPath: '/tmp/does-not-matter',
      );

      // Validation runs before anything touches the filesystem or a window.
      expect(service.validateLocales, returnsNormally);
    });

    test('names the unmapped locale and the supported set', () {
      final service = ScreenshotService(
        config: _config(locales: const [Locale('de', 'DE')]),
        appPath: '/tmp/does-not-matter',
      );

      expect(
        service.validateLocales,
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            allOf(contains('Supported:'), contains('ja')),
          ),
        ),
      );
    });

    test('Traditional Chinese gets its own store listing', () {
      final service = ScreenshotService(
        config: _config(),
        appPath: '/tmp/does-not-matter',
      );

      final simplified = service.storeLocaleNames(const Locale('zh', 'CN'));
      final traditional = service.storeLocaleNames(const Locale('zh', 'TW'));

      expect(simplified.ios, 'zh-Hans');
      expect(simplified.android, 'zh-CN');
      expect(traditional.ios, 'zh-Hant');
      expect(traditional.android, 'zh-TW');
    });

    test('an unregioned locale still resolves by language', () {
      final service = ScreenshotService(
        config: _config(),
        appPath: '/tmp/does-not-matter',
      );

      expect(service.storeLocaleNames(const Locale('ja')).ios, 'ja');
    });

    test('skips the iOS check when only Android is enabled', () {
      // `tr` is mapped for both, but a locale mapped for one platform only
      // should not be rejected because of the platform that is switched off.
      final service = ScreenshotService(
        config: _config(
          locales: const [Locale('tr', 'TR')],
          enableIos: false,
        ),
        appPath: '/tmp/does-not-matter',
      );

      expect(service.validateLocales, returnsNormally);
    });
  });

  group('ScreenshotModeInfo', () {
    test('exposes every mode, macOS included', () {
      expect(
        ScreenshotModeInfo.all.map((m) => m.mode),
        containsAll(ScreenshotMode.values),
      );
    });

    test('macOS has no device frame', () {
      expect(
        ScreenshotModeInfo.macos.toDeviceInfo,
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('phone and tablet produce a frame at the declared size', () {
      expect(ScreenshotModeInfo.phone.toDeviceInfo().screenSize.width, 390);
      expect(ScreenshotModeInfo.tablet.toDeviceInfo().screenSize.width, 834);
    });
  });
}
