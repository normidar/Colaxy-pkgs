import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// How much smaller the on-screen window is than the captured image.
///
/// Store screenshots are far larger than any real display, so the window is
/// shown scaled down and the capture is taken at `pixelRatio: 3`.
const windowScale = 3.3;

/// Pins the desktop window to [size] (scaled by [windowScale]).
///
/// `ScreenshotService` and `ScreenshotModeInfo` used to carry their own copy
/// of this, each with its own `const rate = 3.3`.
Future<void> resizeWindowTo(Size size) async {
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(size / windowScale);
  await windowManager.setMaximumSize(size / windowScale);
  await windowManager.setPosition(const Offset(100, 100));
  await windowManager.setSize(size);
}
