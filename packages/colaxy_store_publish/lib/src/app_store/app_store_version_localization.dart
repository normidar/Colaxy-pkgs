import 'package:meta/meta.dart';

/// One locale's **version-specific** text on an App Store listing.
///
/// Five of the eight fields `colaxy_localization` writes land here. The other
/// three — name, subtitle, privacy policy URL — belong to
/// `AppInfoLocalization`, because they do not change between versions.
///
/// A `null` field means "leave the store alone". As on Google Play, this
/// matters because the API's PATCH is a partial update: an attribute that is
/// not sent is not changed, so `null` and empty string are different requests.
///
/// ## Parameters
///
/// ### Required
/// - **[locale]**: The App Store locale, e.g. `ja`, `zh-Hans`, `en-US`.
///
/// ### Optional
/// - **[id]**: Apple's identifier, when this came from the store.
/// - **[description]**: The long description.
/// - **[keywords]**: Comma-separated search keywords.
/// - **[whatsNew]**: Release notes. Meaningless on a first submission.
/// - **[promotionalText]**: Editable without shipping a new version.
/// - **[marketingUrl]**: Marketing site.
/// - **[supportUrl]**: Support site.
@immutable
class AppStoreVersionLocalization {
  /// Creates a version localization.
  const AppStoreVersionLocalization({
    required this.locale,
    this.id,
    this.description,
    this.keywords,
    this.whatsNew,
    this.promotionalText,
    this.marketingUrl,
    this.supportUrl,
  });

  /// Reads one out of a JSON:API resource object.
  @internal
  factory AppStoreVersionLocalization.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    return AppStoreVersionLocalization(
      id: json['id'] as String?,
      locale: attributes['locale'] as String? ?? '',
      description: attributes['description'] as String?,
      keywords: attributes['keywords'] as String?,
      whatsNew: attributes['whatsNew'] as String?,
      promotionalText: attributes['promotionalText'] as String?,
      marketingUrl: attributes['marketingUrl'] as String?,
      supportUrl: attributes['supportUrl'] as String?,
    );
  }

  /// The App Store locale.
  ///
  /// Sent verbatim. Apple's locale list is not Google Play's — `ja` where
  /// Play wants `ja-JP`, `zh-Hans` where Play wants `zh-CN` — and this
  /// package carries no table of either. `colaxy_localization` already maps
  /// them when it writes the directories.
  final String locale;

  /// Apple's identifier, when this came from the store.
  final String? id;

  /// The long description.
  final String? description;

  /// Comma-separated search keywords.
  final String? keywords;

  /// Release notes.
  final String? whatsNew;

  /// Promotional text, editable without shipping a new version.
  final String? promotionalText;

  /// Marketing site.
  final String? marketingUrl;

  /// Support site.
  final String? supportUrl;

  /// Whether every writable field is unset.
  bool get isEmpty =>
      description == null &&
      keywords == null &&
      whatsNew == null &&
      promotionalText == null &&
      marketingUrl == null &&
      supportUrl == null;

  /// The attributes to send, dropping the ones left unset.
  ///
  /// Omitting rather than sending `null` is the difference between "leave it"
  /// and "clear it" on this API.
  @internal
  Map<String, dynamic> toAttributes() => <String, dynamic>{
    'description': ?description,
    'keywords': ?keywords,
    'whatsNew': ?whatsNew,
    'promotionalText': ?promotionalText,
    'marketingUrl': ?marketingUrl,
    'supportUrl': ?supportUrl,
  };

  @override
  String toString() => 'AppStoreVersionLocalization($locale)';
}
