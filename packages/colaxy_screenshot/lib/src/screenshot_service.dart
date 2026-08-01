import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:colaxy_screenshot/colaxy_screenshot.dart';
import 'package:colaxy_screenshot/src/utils/window.dart';
import 'package:device_frame_plus/device_frame_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' hide Color, Image;
import 'package:image/image.dart' as img show Image;

/// Locale mapping for Android
const _androidLocaleMap = {
  'en': 'en-US',
  'ja': 'ja-JP',
  'zh': 'zh-CN',
  'es': 'es-ES',
  'pt': 'pt-PT',
  'tr': 'tr-TR',
};

/// Locale mapping for iOS
const _iOSLocaleMap = {
  'en': 'en-US',
  'ja': 'ja',
  'zh': 'zh-Hans',
  'es': 'es-ES',
  'pt': 'pt-PT',
  'tr': 'tr',
};

/// Resolves the store directory name for [locale], or explains what is missing.
///
/// These maps only cover a handful of languages. Reading them with `!` turned
/// every unmapped locale into a bare null-check crash halfway through a capture
/// run, so look them up through here instead.
String _storeLocaleName(
  Map<String, String> map,
  Locale locale,
  String platform,
) {
  final name = map[locale.languageCode];
  if (name == null) {
    throw ArgumentError.value(
      locale.languageCode,
      'locale',
      'colaxy_screenshot has no $platform store locale mapped for this '
          'language. Supported: ${map.keys.join(', ')}.',
    );
  }
  return name;
}

String _iosLocaleName(Locale locale) =>
    _storeLocaleName(_iOSLocaleMap, locale, 'iOS');

String _androidLocaleName(Locale locale) =>
    _storeLocaleName(_androidLocaleMap, locale, 'Android');

/// App Store Connect device slot for phone screenshots.
///
/// Apple changes the accepted display sizes over time; these are the folder
/// name fragments Fastlane matches on.
const kIosPhoneDeviceName = 'iphone65';

/// App Store Connect device slot for tablet screenshots.
const kIosTabletDeviceName = 'ipadPro13';

/// App Store Connect device slot for macOS screenshots.
const kMacDeviceName = 'mac';

/// Main screenshot service
class ScreenshotService {
  ScreenshotService({required this.config, required this.appPath});

  final ScreenshotConfig config;

  final String appPath;

  GlobalKey? _appKey;

  // MacBook Pro の screenBounds (device.dart に定義されている実際のディスプレイ領域)
  // screenPath・screenSize をこの領域全体に上書きすることでフルスクリーン表示にする
  static final DeviceInfo _macBookProFullScreen = () {
    const pixelRatio = 2.0;
    const screenBounds = Rect.fromLTWH(346.68, 98.2, 2298.82, 1437.32);
    return Devices.macOS.macBookPro.copyWith(
      screenPath: Path()..addRect(screenBounds),
      screenSize: Size(
        screenBounds.width / pixelRatio,
        screenBounds.height / pixelRatio,
      ),
    );
  }();

  /// Run the screenshot workflow
  Future<void> executeScreenshots() async {
    // Fail before capturing anything rather than partway through a long run.
    validateLocales();

    try {
      if (config.enableAndroid) {
        await getFeatureGraphicScreenshot();
      }

      var isFirst = true;
      final modes = [
        if (config.enableIos || config.enableAndroid) ...[
          ScreenshotModeInfo.phone,
          ScreenshotModeInfo.tablet,
        ],
        if (config.enableMacos) ScreenshotModeInfo.macos,
      ];
      // Capture screenshots for each combination of device, locale, and page
      for (final mode in modes) {
        await mode.setWindowToSize();
        for (final locale in config.supportedLocales) {
          for (final page in config.pages) {
            await _capturePageScreenshot(
              locale: locale,
              page: page,
              modeInfo: mode,
              // The very first capture has to wait for the app to warm up.
              delay: isFirst ? config.firstCaptureDelay : config.captureDelay,
            );
            isFirst = false;
          }
        }
      }
    } finally {
      // Always restore the config file. Leaving `launch_mode: screenshot` in
      // place means the next normal launch silently starts capturing again.
      await resetJsonConfig();
    }

    // exit the app
    debugPrint('Screenshots taken, exiting the app...');
    exit(0);
  }

  /// Verifies every configured locale can be mapped to a store directory.
  ///
  /// Called at the start of [executeScreenshots] so a bad locale fails before
  /// any capture work happens.
  @visibleForTesting
  void validateLocales() {
    for (final locale in config.supportedLocales) {
      if (config.enableIos || config.enableMacos) _iosLocaleName(locale);
      if (config.enableAndroid) _androidLocaleName(locale);
    }
  }

  /// Feature Graphic Page generate
  Future<void> getFeatureGraphicScreenshot() async {
    _appKey = GlobalKey();

    final Widget appWidget = ProviderScope(
      overrides: config.overrides,
      child: config.easyLocalizationWrapper(
        Builder(
          builder: (context) {
            return FutureBuilder(
              future: () async {
                Intl.defaultLocale = 'en';
                await context.setLocale(const Locale('en', 'US'));
                return null;
              }(),
              builder: (_, _) => config.wrapFunction(
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF8BC34A), // Light Green
                        Color(0xFF009688), // Teal
                      ],
                    ),
                  ),
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 200,
                          child: Transform.rotate(
                            angle:
                                -math.pi /
                                6, // Larger numbers reduce the rotation angle
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: Image.asset(
                                config.featureGraphicIconAsset,
                                width: 400,
                                height: 400,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -50,
                          right: 200,
                          child: Transform.rotate(
                            angle:
                                math.pi /
                                6, // Larger numbers reduce the rotation angle
                            child: DeviceFrame(
                              device: const ScreenshotModeInfo(
                                mode: ScreenshotMode.phone,
                                deviceSize: Size(642, 1389),
                              ).toDeviceInfo(),
                              screen: config.featureGraphicPage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await resizeWindowTo(const Size(1024, 500));
    runApp(
      RepaintBoundary(
        key: _appKey,
        child: appWidget,
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    await WidgetsBinding.instance.endOfFrame;
    final imageBytes = await _captureBoundary('feature graphic');
    final pngImage = _decode(imageBytes, 'feature graphic');
    final resizedImage = copyResize(pngImage, width: 1024, height: 500);
    File(
      '$appPath/fastlane/metadata/android/featureGraphic.png',
    ).writeAsBytesSync(encodePng(resizedImage));
  }

  /// Build the app widget with the given locale
  Widget _buildAppWithLocale({
    required Locale locale,
    required ScreenshotPageInfo page,
    required ScreenshotModeInfo modeInfo,
  }) {
    _appKey = GlobalKey();

    final Widget appWidget = ProviderScope(
      overrides: [
        ...config.overrides,
        ...page.overrides ?? [],
      ],
      child: config.easyLocalizationWrapper(
        Builder(
          builder: (context) {
            return FutureBuilder(
              future: () async {
                Intl.defaultLocale = locale.languageCode;
                await context.setLocale(locale);
                return null;
              }(),
              builder: (_, _) {
                final innerContent = Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: DeviceFrame(
                    device: switch (modeInfo.mode) {
                      ScreenshotMode.phone => Devices.ios.iPhone13,
                      ScreenshotMode.tablet => Devices.ios.iPad,
                      ScreenshotMode.macos => _macBookProFullScreen,
                    },
                    screen: page.widget(),
                  ),
                );
                return config.wrapFunction(
                  _buildMarketingLayout(innerContent, page, modeInfo),
                );
              },
            );
          },
        ),
      ),
    );

    return RepaintBoundary(
      key: _appKey,
      child: appWidget,
    );
  }

  /// Build the marketing layout (background + title + device frame)
  Widget _buildMarketingLayout(
    Widget deviceFrame,
    ScreenshotPageInfo page,
    ScreenshotModeInfo modeInfo,
  ) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Container(
        width: modeInfo.deviceSize.width,
        height: modeInfo.deviceSize.height,
        // Per-page settings win over the run-wide config; both used to be
        // ignored in favour of hardcoded values.
        color: page.backgroundColor ?? config.backgroundColor,
        child: Column(
          children: [
            // Title area at the top
            Padding(
              padding: EdgeInsets.fromLTRB(
                40,
                switch (modeInfo.mode) {
                  ScreenshotMode.macos => 40,
                  _ => 80,
                },
                40,
                20,
              ),
              child: Text(
                page.titleTextKey.tr(),
                style:
                    page.titleStyle ??
                    config.titleStyle ??
                    kDefaultScreenshotTitleStyle,
                textAlign: TextAlign.center,
              ),
            ),

            // Centered device frame
            Expanded(
              child: Center(
                child: deviceFrame,
              ),
            ),

            // Bottom spacing
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  /// Capture and upload a screenshot for a single page
  Future<void> _capturePageScreenshot({
    required Locale locale,
    required ScreenshotPageInfo page,
    required ScreenshotModeInfo modeInfo,
    required Duration delay,
  }) async {
    // Launch the app with runApp
    final app = _buildAppWithLocale(
      locale: locale,
      page: page,
      modeInfo: modeInfo,
    );

    runApp(app);

    // Wait until the app finishes rendering
    await Future<void>.delayed(delay);

    // Wait for the frame callback to ensure rendering is complete
    await WidgetsBinding.instance.endOfFrame;

    // Retrieve the screenshot from the RepaintBoundary
    final what = '${page.name} (${modeInfo.mode.name}, $locale)';
    final imageBytes = await _captureBoundary(what);
    final image = _decode(imageBytes, what);

    final index = page.index;
    final screenshotId = page.name;

    // image resize
    final width = modeInfo.deviceSize.width.toInt();
    final height = modeInfo.deviceSize.height.toInt();
    final resizedImage = copyResize(image, width: width, height: height);

    switch (modeInfo.mode) {
      case ScreenshotMode.phone:
        if (config.enableIos) {
          final iOSLocaleName = _iosLocaleName(locale);
          final iphonePath = '$appPath/fastlane/screenshots/$iOSLocaleName';
          Directory(iphonePath).createSync(recursive: true);
          _deleteExistingScreenshots(
            directoryPath: iphonePath,
            deviceName: kIosPhoneDeviceName,
            index: index,
          );
          File(
            '$iphonePath/${index}_${kIosPhoneDeviceName}_$index.$screenshotId.png',
          ).writeAsBytesSync(encodePng(resizedImage));
        }
        if (config.enableAndroid) {
          final androidLocaleName = _androidLocaleName(locale);
          final androidPhonePath =
              '$appPath/fastlane/metadata/android/$androidLocaleName/images/phoneScreenshots';
          final androidSevenInchPath =
              '$appPath/fastlane/metadata/android/$androidLocaleName/images/sevenInchScreenshots';
          Directory(androidPhonePath).createSync(recursive: true);
          Directory(androidSevenInchPath).createSync(recursive: true);
          File(
            '$androidPhonePath/${index}_$androidLocaleName.png',
          ).writeAsBytesSync(encodePng(resizedImage));
          File(
            '$androidSevenInchPath/${index}_$androidLocaleName.png',
          ).writeAsBytesSync(encodePng(resizedImage));
        }

      case ScreenshotMode.tablet:
        if (config.enableIos) {
          final iOSLocaleName = _iosLocaleName(locale);
          final ipadPath = '$appPath/fastlane/screenshots/$iOSLocaleName';
          Directory(ipadPath).createSync(recursive: true);
          _deleteExistingScreenshots(
            directoryPath: ipadPath,
            deviceName: kIosTabletDeviceName,
            index: index,
          );
          File(
            '$ipadPath/${index}_${kIosTabletDeviceName}_$index.$screenshotId.png',
          ).writeAsBytesSync(encodePng(resizedImage));
        }
        if (config.enableAndroid) {
          final androidLocaleName = _androidLocaleName(locale);
          final androidTenInchPath =
              '$appPath/fastlane/metadata/android/$androidLocaleName/images/tenInchScreenshots';
          Directory(androidTenInchPath).createSync(recursive: true);
          File(
            '$androidTenInchPath/${index}_$androidLocaleName.png',
          ).writeAsBytesSync(encodePng(resizedImage));
        }

      case ScreenshotMode.macos:
        // save to macOS screenshot folder
        final macLocaleName = _iosLocaleName(locale);
        final macPath = '$appPath/fastlane/screenshots/$macLocaleName';
        Directory(macPath).createSync(recursive: true);

        _deleteExistingScreenshots(
          directoryPath: macPath,
          deviceName: kMacDeviceName,
          index: index,
        );

        File(
          '$macPath/${index}_${kMacDeviceName}_$index.$screenshotId.png',
        ).writeAsBytesSync(encodePng(resizedImage));
    }
  }

  /// Renders the current RepaintBoundary to PNG bytes.
  ///
  /// Replaces a chain of `!` operators whose failure mode was an unattributed
  /// "Null check operator used on a null value".
  Future<Uint8List> _captureBoundary(String what) async {
    final currentContext = _appKey?.currentContext;
    if (currentContext == null || !currentContext.mounted) {
      throw StateError('Screenshot surface for $what was never mounted.');
    }
    final boundary = currentContext.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError(
        'Screenshot surface for $what is not a RepaintBoundary.',
      );
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) {
      throw StateError('Failed to encode the screenshot for $what.');
    }
    return bytes;
  }

  img.Image _decode(Uint8List bytes, String what) {
    final decoded = decodePng(bytes);
    if (decoded == null) {
      throw StateError('Failed to decode the captured PNG for $what.');
    }
    return decoded;
  }

  /// Remove existing iPhone screenshot files
  /// Pattern: ${index}_iphone65_$index.*.png
  void _deleteExistingScreenshots({
    required String directoryPath,
    required String deviceName,
    required int index,
  }) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) return;

    // Find and delete files that match the pattern
    final pattern = RegExp(
      '^${index}_${deviceName}_$index'
      r'\..*\.png$',
    );

    final files = directory.listSync().whereType<File>().where(
      (file) => pattern.hasMatch(file.uri.pathSegments.last),
    );

    for (final file in files) {
      try {
        file.deleteSync();
        debugPrint('Deleted: ${file.path}');
      } on FileSystemException catch (e) {
        debugPrint('Failed to delete ${file.path}: $e');
      }
    }
  }
}
