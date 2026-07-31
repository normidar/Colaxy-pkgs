import 'package:colaxy_screenshot/src/utils/window.dart';
import 'package:device_frame_plus/device_frame_plus.dart';
import 'package:flutter/widgets.dart';

/// The device class a screenshot is captured for.
enum ScreenshotMode { phone, tablet, macos }

/// Capture settings for one [ScreenshotMode].
class ScreenshotModeInfo {
  /// Creates capture settings for [mode] at [deviceSize].
  const ScreenshotModeInfo({
    required this.mode,
    required this.deviceSize,
  });

  /// iPhone 6.5" store dimensions.
  static const phone = ScreenshotModeInfo(
    mode: ScreenshotMode.phone,
    deviceSize: Size(1284, 2778),
  );

  /// iPad Pro 12.9" store dimensions.
  static const tablet = ScreenshotModeInfo(
    mode: ScreenshotMode.tablet,
    deviceSize: Size(2048, 2732),
  );

  /// Mac App Store dimensions.
  static const macos = ScreenshotModeInfo(
    mode: ScreenshotMode.macos,
    deviceSize: Size(2560, 1600),
  );

  /// Every mode, in capture order.
  static const all = <ScreenshotModeInfo>[phone, tablet, macos];

  /// The device class this describes.
  final ScreenshotMode mode;

  /// Output image size for this mode.
  final Size deviceSize;

  /// Resizes the desktop window so the capture surface matches [deviceSize].
  ///
  /// The window is shown at 1/[windowScale] of the output size — a 2778px tall
  /// phone screenshot does not fit on a real display.
  Future<void> setWindowToSize() => resizeWindowTo(deviceSize);

  DeviceInfo toDeviceInfo() {
    switch (mode) {
      case ScreenshotMode.phone:
        return DeviceInfo.genericPhone(
          platform: TargetPlatform.iOS,
          id: 'iphone-14-pro',
          name: 'iPhone 14 Pro',
          screenSize: const Size(390, 844),
          safeAreas: const EdgeInsets.only(
            top: 10,
            bottom: 10,
          ),
          rotatedSafeAreas: const EdgeInsets.only(
            left: 10,
            right: 10,
            bottom: 10,
          ),
          pixelRatio: 3,
        );
      case ScreenshotMode.tablet:
        return DeviceInfo.genericTablet(
          platform: TargetPlatform.iOS,
          id: 'ipad_pro_11',
          name: 'iPad Pro 11"',
          screenSize: const Size(834, 1194),
          safeAreas: const EdgeInsets.only(
            top: 20,
            bottom: 20,
          ),
          rotatedSafeAreas: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20,
          ),
        );
      case ScreenshotMode.macos:
        throw UnsupportedError('macOS mode does not use a device frame');
    }
  }
}
