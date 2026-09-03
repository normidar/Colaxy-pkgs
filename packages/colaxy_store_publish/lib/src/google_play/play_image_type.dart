/// A slot an image can occupy in a Google Play store listing.
///
/// The names match `androidpublisher`'s `imageType` values exactly, and also
/// match the directory names `colaxy_screenshot` writes and `fastlane supply`
/// reads. That is not a coincidence — both follow the same convention — but it
/// does mean a directory name can be turned into a slot without a translation
/// table.
///
/// `appImageTypeUnspecified` is a tenth value in the API that this enum
/// deliberately omits: its own discovery document says "Do not use".
///
/// ## Example
///
/// ```dart
/// final slot = PlayImageType.byDirectoryName('phoneScreenshots');
/// ```
enum PlayImageType {
  /// Phone screenshots. Between 2 and 8 per locale.
  phoneScreenshots('phoneScreenshots'),

  /// 7-inch tablet screenshots.
  sevenInchScreenshots('sevenInchScreenshots'),

  /// 10-inch tablet screenshots.
  tenInchScreenshots('tenInchScreenshots'),

  /// Android TV screenshots.
  tvScreenshots('tvScreenshots'),

  /// Wear OS screenshots.
  wearScreenshots('wearScreenshots'),

  /// The app icon shown on the store listing.
  icon('icon'),

  /// The banner above the listing.
  featureGraphic('featureGraphic'),

  /// The Android TV banner.
  tvBanner('tvBanner');

  /// Creates a slot with the wire name Google Play uses for it.
  const PlayImageType(this.wireName);

  /// The value `androidpublisher` expects in its `imageType` parameter.
  ///
  /// Also the directory name under `images/` for the multi-image slots, and
  /// the file stem for the single-image ones.
  final String wireName;

  /// The slot [name] refers to, or `null` if it names no slot.
  ///
  /// Returns `null` rather than throwing because callers scan directories
  /// they do not control: `fastlane/metadata/android/<locale>/images/` can
  /// hold anything, and an unrecognised entry is something to skip, not a
  /// reason to fail the run.
  static PlayImageType? byDirectoryName(String name) {
    for (final type in values) {
      if (type.wireName == name) return type;
    }
    return null;
  }

  /// Whether the slot holds an ordered set of images rather than exactly one.
  ///
  /// Uploading to a single-image slot replaces what is there; uploading to a
  /// set appends to it. That difference is why replacing screenshots needs
  /// `deleteall` first and replacing a feature graphic does not.
  bool get holdsMany => switch (this) {
    PlayImageType.phoneScreenshots ||
    PlayImageType.sevenInchScreenshots ||
    PlayImageType.tenInchScreenshots ||
    PlayImageType.tvScreenshots ||
    PlayImageType.wearScreenshots => true,
    PlayImageType.icon ||
    PlayImageType.featureGraphic ||
    PlayImageType.tvBanner => false,
  };
}
