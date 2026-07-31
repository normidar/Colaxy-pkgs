## 0.8.0

### Breaking
- `ScreenshotConfig.captureDelay` is now `final`. The run used to mutate it in
  place to lengthen the first capture; use `firstCaptureDelay` instead.

### Fixed
- A locale with no store mapping is reported up front, naming the locale and
  the supported set, instead of crashing partway through a run on `!`.
- The config file is restored in a `finally` block. If a run threw, the app was
  left in `launch_mode: screenshot` and would start capturing again on the next
  normal launch.
- `backgroundColor` and `titleStyle` (on both `ScreenshotConfig` and
  `ScreenshotPageInfo`) are actually applied; they were previously ignored in
  favour of hardcoded values. The defaults match the old hardcoded ones.
- The `!` chains around capturing and decoding now raise errors naming the page,
  mode and locale instead of "Null check operator used on a null value".
- `getJsonConfig` reports which key in `assets/config.json` is not a string,
  rather than surfacing a `CastError` from an unrelated line later on.

### Added
- `ScreenshotConfig.firstCaptureDelay` and
  `ScreenshotConfig.featureGraphicIconAsset` (the icon path was hardcoded to
  `assets/app_icons/icon.png`).

### Changed
- `ScreenshotModeInfo.all` includes macOS and its entries are `const`; they were
  mutable statics and the list omitted macOS.
- Window resizing lives in one place (`resizeWindowTo`); it was duplicated with a
  separate copy of the `3.3` scale factor in each.
- iOS/macOS store device slots are named constants
  (`kIosPhoneDeviceName`, `kIosTabletDeviceName`, `kMacDeviceName`).

## 0.7.1

 - **FIX**: reset repo link and homepage link.
 - **FIX**: use melos.
 - **FEAT**(colaxy_screenshot): release v0.7.0 with macOS support and window_manager migration.

## 0.7.0

- Add macOS screenshot support (`enableMacos: true`) with 2560×1600 resolution for Mac App Store.
- Add `enableIos` and `enableAndroid` flags to `ScreenshotConfig` for per-platform control.
- Replace `window_size` with `window_manager` for Swift Package Manager compatibility on macOS.
- Fix marketing layout to use mode-specific dimensions instead of a fixed 1080×1920 size.
- Add full-screen capture mode.

## 0.6.0+1

 - **FIX**: reset repo link and homepage link.
 - **FIX**: use melos.

## 0.6.0

- Remove imghippoApiKey from config.
- Reset config file after screenshots are taken.
- Use json format for config file.(config.yaml is deprecated, use config.json instead.)
- Exit the app after screenshots are taken.

## 0.5.0

- Update dependencies.

## 0.4.1

- Use real iOS device frames.

## 0.4.0

- Fix some issues.

## 0.3.0

- Add easyLocalizationWrapper to config.

## 0.2.0

- Add support for Spanish, Portuguese, and Turkish.

## 0.1.1

- Add screenshotId to screenshot file name.
- Delete existing screenshots before saving new screenshots.

## 0.1.0

- Remove indexToScreenshot from config.

## 0.0.3

- Fix First screenshot loading issue.

## 0.0.2

- Fix First screenshot loading issue.

## 0.0.1

- Initial release.
