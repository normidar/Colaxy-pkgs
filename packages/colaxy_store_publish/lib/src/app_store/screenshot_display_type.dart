/// A device slot a screenshot can occupy on an App Store listing.
///
/// All 33 values from the App Store Connect API 4.4.1 specification, in the
/// order the spec lists them. Nothing is left out: an omitted value is one a
/// caller cannot express, and Apple adds devices faster than this package
/// will be updated.
///
/// **This is where the App Store and Google Play stop resembling each other.**
/// Play has nine `imageType` values whose names are exactly the directory
/// names `colaxy_screenshot` writes, so Android needs no translation table at
/// all. Apple has 33 values that match nothing on disk, so [byCaptureName]
/// exists and has to be maintained by hand.
///
/// ## Example
///
/// ```dart
/// final slot = ScreenshotDisplayType.byCaptureName('iphone65');
/// ```
enum ScreenshotDisplayType {
  /// iPhone 6.7-inch.
  appIphone67('APP_IPHONE_67'),

  /// iPhone 6.1-inch.
  appIphone61('APP_IPHONE_61'),

  /// iPhone 6.5-inch.
  appIphone65('APP_IPHONE_65'),

  /// iPhone 5.8-inch.
  appIphone58('APP_IPHONE_58'),

  /// iPhone 5.5-inch.
  appIphone55('APP_IPHONE_55'),

  /// iPhone 4.7-inch.
  appIphone47('APP_IPHONE_47'),

  /// iPhone 4.0-inch.
  appIphone40('APP_IPHONE_40'),

  /// iPhone 3.5-inch.
  appIphone35('APP_IPHONE_35'),

  /// iPad Pro (3rd generation) 12.9-inch.
  ///
  /// Also where the 13-inch iPad's screenshots land, despite the name — see
  /// [byCaptureName].
  appIpadPro3Gen129('APP_IPAD_PRO_3GEN_129'),

  /// iPad Pro (3rd generation) 11-inch.
  appIpadPro3Gen11('APP_IPAD_PRO_3GEN_11'),

  /// iPad Pro 12.9-inch.
  appIpadPro129('APP_IPAD_PRO_129'),

  /// iPad 10.5-inch.
  appIpad105('APP_IPAD_105'),

  /// iPad 9.7-inch.
  appIpad97('APP_IPAD_97'),

  /// macOS.
  appDesktop('APP_DESKTOP'),

  /// Apple Watch Ultra.
  appWatchUltra('APP_WATCH_ULTRA'),

  /// Apple Watch Series 10.
  appWatchSeries10('APP_WATCH_SERIES_10'),

  /// Apple Watch Series 7.
  appWatchSeries7('APP_WATCH_SERIES_7'),

  /// Apple Watch Series 4.
  appWatchSeries4('APP_WATCH_SERIES_4'),

  /// Apple Watch Series 3.
  appWatchSeries3('APP_WATCH_SERIES_3'),

  /// Apple TV.
  appAppleTv('APP_APPLE_TV'),

  /// Apple Vision Pro.
  appAppleVisionPro('APP_APPLE_VISION_PRO'),

  /// iMessage app, iPhone 6.7-inch.
  imessageAppIphone67('IMESSAGE_APP_IPHONE_67'),

  /// iMessage app, iPhone 6.1-inch.
  imessageAppIphone61('IMESSAGE_APP_IPHONE_61'),

  /// iMessage app, iPhone 6.5-inch.
  imessageAppIphone65('IMESSAGE_APP_IPHONE_65'),

  /// iMessage app, iPhone 5.8-inch.
  imessageAppIphone58('IMESSAGE_APP_IPHONE_58'),

  /// iMessage app, iPhone 5.5-inch.
  imessageAppIphone55('IMESSAGE_APP_IPHONE_55'),

  /// iMessage app, iPhone 4.7-inch.
  imessageAppIphone47('IMESSAGE_APP_IPHONE_47'),

  /// iMessage app, iPhone 4.0-inch.
  imessageAppIphone40('IMESSAGE_APP_IPHONE_40'),

  /// iMessage app, iPad Pro (3rd generation) 12.9-inch.
  imessageAppIpadPro3Gen129('IMESSAGE_APP_IPAD_PRO_3GEN_129'),

  /// iMessage app, iPad Pro (3rd generation) 11-inch.
  imessageAppIpadPro3Gen11('IMESSAGE_APP_IPAD_PRO_3GEN_11'),

  /// iMessage app, iPad Pro 12.9-inch.
  imessageAppIpadPro129('IMESSAGE_APP_IPAD_PRO_129'),

  /// iMessage app, iPad 10.5-inch.
  imessageAppIpad105('IMESSAGE_APP_IPAD_105'),

  /// iMessage app, iPad 9.7-inch.
  imessageAppIpad97('IMESSAGE_APP_IPAD_97');

  /// Creates a slot with the wire name App Store Connect uses for it.
  const ScreenshotDisplayType(this.wireName);

  /// Names `colaxy_screenshot` puts in its capture file names, mapped to the
  /// slot the App Store keeps those captures in.
  ///
  /// `colaxy_screenshot` writes `fastlane/screenshots/<locale>/` with names
  /// like `1_iphone65_1.welcome.png`, where the middle segment names the
  /// device. Those names come from that package's own constants
  /// (`kIosPhoneDeviceName`, `kIosTabletDeviceName`, `kMacDeviceName`) and
  /// match no API value, so this table is the bridge.
  ///
  /// > ⚠️ **`ipadPro13` is not verified against a real account.** The 13-inch
  /// > iPad is reported to land under `APP_IPAD_PRO_3GEN_129` despite the
  /// > name saying 12.9 — Apple's website labels and the API's generation
  /// > numbers are known to disagree. That report is a forum post, not the
  /// > specification. Confirm it before trusting a release to it.
  static const _captureNames = <String, ScreenshotDisplayType>{
    'iphone65': ScreenshotDisplayType.appIphone65,
    'iphone67': ScreenshotDisplayType.appIphone67,
    'iphone61': ScreenshotDisplayType.appIphone61,
    'iphone58': ScreenshotDisplayType.appIphone58,
    'iphone55': ScreenshotDisplayType.appIphone55,
    'ipadPro13': ScreenshotDisplayType.appIpadPro3Gen129,
    'ipadPro129': ScreenshotDisplayType.appIpadPro129,
    'ipadPro11': ScreenshotDisplayType.appIpadPro3Gen11,
    'mac': ScreenshotDisplayType.appDesktop,
  };

  /// The value App Store Connect expects in `screenshotDisplayType`.
  final String wireName;

  /// Every capture name this package knows how to place, sorted.
  static List<String> get captureNames =>
      _captureNames.keys.toList(growable: false)..sort();

  /// The slot [wireName] names, or `null` if it names none.
  static ScreenshotDisplayType? byWireName(String wireName) {
    for (final type in values) {
      if (type.wireName == wireName) return type;
    }
    return null;
  }

  /// The slot a `colaxy_screenshot` capture named [captureName] belongs in.
  ///
  /// Answers `null` for a name this package has no mapping for, so a caller
  /// scanning a directory can report it rather than guess. Guessing here
  /// would put screenshots in the wrong device slot, which the store accepts
  /// and a human then has to notice.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[captureName]**: The device segment of the file name, e.g.
  ///   `iphone65`.
  static ScreenshotDisplayType? byCaptureName(String captureName) =>
      _captureNames[captureName];

  /// Whether this slot is for an iMessage app rather than the app itself.
  bool get isIMessage => wireName.startsWith('IMESSAGE_');
}
