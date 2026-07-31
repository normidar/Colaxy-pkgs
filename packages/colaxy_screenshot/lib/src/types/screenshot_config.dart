import 'package:colaxy_screenshot/src/types/screenshot_page_info.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';

typedef EasyLocalizationWrapper = EasyLocalization Function(Widget);

/// Default background behind the device frame in a marketing screenshot.
const kDefaultScreenshotBackgroundColor = Color.fromARGB(255, 216, 255, 239);

/// Default style for the marketing title above the device frame.
const kDefaultScreenshotTitleStyle = TextStyle(
  color: Color.fromARGB(255, 25, 178, 255),
  fontSize: 48,
  fontWeight: FontWeight.bold,
  height: 1.2,
  decoration: TextDecoration.none,
);

/// Configuration class for screenshots
class ScreenshotConfig {
  ScreenshotConfig({
    required this.featureGraphicPage,
    required this.supportedLocales,
    required this.pages,
    required this.wrapFunction,
    required this.overrides,
    required this.easyLocalizationWrapper,
    this.captureDelay = const Duration(milliseconds: 500),
    this.firstCaptureDelay = const Duration(seconds: 3),
    this.featureGraphicIconAsset = 'assets/app_icons/icon.png',
    this.backgroundColor = kDefaultScreenshotBackgroundColor,
    this.titleStyle,
    this.enableIos = true,
    this.enableAndroid = true,
    this.enableMacos = false,
  });

  final Widget featureGraphicPage;

  final List<Override> overrides;

  final EasyLocalizationWrapper easyLocalizationWrapper;

  /// Wrapper function for screenshot pages
  final Widget Function(Widget) wrapFunction;

  /// List of supported locales
  final List<Locale> supportedLocales;

  /// List of pages to capture
  final List<ScreenshotPageInfo> pages;

  /// Delay between screenshots (default 500ms).
  final Duration captureDelay;

  /// Delay before the very first capture.
  ///
  /// The first frame has to wait for the app to warm up, so this is longer
  /// than [captureDelay]. This used to be applied by mutating [captureDelay]
  /// mid-run.
  final Duration firstCaptureDelay;

  /// Asset path of the app icon drawn onto the Android feature graphic.
  ///
  /// Resolved against the host app's assets.
  final String featureGraphicIconAsset;

  /// Background color behind the device frame.
  final Color backgroundColor;

  /// Title text style. Falls back to [kDefaultScreenshotTitleStyle].
  final TextStyle? titleStyle;

  /// Whether to capture iOS screenshots (default: true)
  final bool enableIos;

  /// Whether to capture Android screenshots (default: true)
  final bool enableAndroid;

  /// Whether to capture macOS screenshots (default: false)
  final bool enableMacos;
}
