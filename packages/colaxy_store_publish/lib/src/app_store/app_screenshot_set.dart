import 'package:colaxy_store_publish/src/app_store/screenshot_display_type.dart';
import 'package:meta/meta.dart';

/// The screenshots for one device slot in one locale.
///
/// Sets hang off an `appStoreVersionLocalization`, so the full chain to a
/// screenshot is **version → localization → set → screenshot**. Google Play
/// reaches the equivalent in one call.
///
/// **`appScreenshotSets` has no `PATCH`** (verified against the
/// specification): `POST`, `GET` and `DELETE` only. Replacing a set means
/// deleting it and building a new one, which is why replacement is opt-in
/// here exactly as it is on the Android side.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: Apple's identifier for the set.
///
/// ### Optional
/// - **[displayType]**: Which device slot, when this package recognises it.
/// - **[rawDisplayType]**: The wire value, kept even when unrecognised.
@immutable
class AppScreenshotSet {
  /// Creates a screenshot set.
  const AppScreenshotSet({
    required this.id,
    this.displayType,
    this.rawDisplayType,
  });

  /// Reads a set out of a JSON:API resource object.
  @internal
  factory AppScreenshotSet.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    final raw = attributes['screenshotDisplayType'] as String?;
    return AppScreenshotSet(
      id: json['id'] as String? ?? '',
      displayType: raw == null
          ? null
          : ScreenshotDisplayType.byWireName(raw),
      rawDisplayType: raw,
    );
  }

  /// Apple's identifier for the set.
  final String id;

  /// Which device slot, when this package recognises it.
  final ScreenshotDisplayType? displayType;

  /// The wire value, kept even when unrecognised.
  ///
  /// Apple adds devices, and a set this package cannot name is still a set
  /// that exists on the store. Dropping the value would make it invisible.
  final String? rawDisplayType;

  @override
  String toString() =>
      'AppScreenshotSet($id, ${rawDisplayType ?? '?'})';
}
