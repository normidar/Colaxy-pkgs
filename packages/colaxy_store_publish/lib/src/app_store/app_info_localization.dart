import 'package:meta/meta.dart';

/// One locale's **app-wide** text on an App Store listing.
///
/// Three of the eight fields `colaxy_localization` writes land here, and they
/// are the ones that do not change between versions. The other five belong to
/// `AppStoreVersionLocalization`.
///
/// ## Parameters
///
/// ### Required
/// - **[locale]**: The App Store locale, e.g. `ja`, `zh-Hans`.
///
/// ### Optional
/// - **[id]**: Apple's identifier, when this came from the store.
/// - **[name]**: The app's name on the store.
/// - **[subtitle]**: The line under the name.
/// - **[privacyPolicyUrl]**: Privacy policy address.
/// - **[privacyChoicesUrl]**: Privacy choices address.
/// - **[privacyPolicyText]**: Privacy policy body, for tvOS.
@immutable
class AppInfoLocalization {
  /// Creates an app info localization.
  const AppInfoLocalization({
    required this.locale,
    this.id,
    this.name,
    this.subtitle,
    this.privacyPolicyUrl,
    this.privacyChoicesUrl,
    this.privacyPolicyText,
  });

  /// Reads one out of a JSON:API resource object.
  @internal
  factory AppInfoLocalization.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    return AppInfoLocalization(
      id: json['id'] as String?,
      locale: attributes['locale'] as String? ?? '',
      name: attributes['name'] as String?,
      subtitle: attributes['subtitle'] as String?,
      privacyPolicyUrl: attributes['privacyPolicyUrl'] as String?,
      privacyChoicesUrl: attributes['privacyChoicesUrl'] as String?,
      privacyPolicyText: attributes['privacyPolicyText'] as String?,
    );
  }

  /// The App Store locale.
  final String locale;

  /// Apple's identifier, when this came from the store.
  final String? id;

  /// The app's name on the store.
  final String? name;

  /// The line under the name.
  final String? subtitle;

  /// Privacy policy address.
  final String? privacyPolicyUrl;

  /// Privacy choices address.
  final String? privacyChoicesUrl;

  /// Privacy policy body, for tvOS.
  final String? privacyPolicyText;

  /// Whether every writable field is unset.
  bool get isEmpty =>
      name == null &&
      subtitle == null &&
      privacyPolicyUrl == null &&
      privacyChoicesUrl == null &&
      privacyPolicyText == null;

  /// The attributes to send, dropping the ones left unset.
  @internal
  Map<String, dynamic> toAttributes() => <String, dynamic>{
    'name': ?name,
    'subtitle': ?subtitle,
    'privacyPolicyUrl': ?privacyPolicyUrl,
    'privacyChoicesUrl': ?privacyChoicesUrl,
    'privacyPolicyText': ?privacyPolicyText,
  };

  @override
  String toString() => 'AppInfoLocalization($locale)';
}
