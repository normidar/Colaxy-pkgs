import 'package:colaxy_store_publish/src/app_store/app_info_localization.dart';
import 'package:colaxy_store_publish/src/app_store/app_store_version_localization.dart';
import 'package:meta/meta.dart';

/// One locale's App Store text as it sits on disk.
///
/// **The eight files split across two API resources**, three one way and five
/// the other:
///
/// | file | resource | attribute |
/// |---|---|---|
/// | `name.txt` | AppInfoLocalization | `name` |
/// | `subtitle.txt` | AppInfoLocalization | `subtitle` |
/// | `privacy_url.txt` | AppInfoLocalization | `privacyPolicyUrl` |
/// | `description.txt` | AppStoreVersionLocalization | `description` |
/// | `keywords.txt` | AppStoreVersionLocalization | `keywords` |
/// | `release_notes.txt` | AppStoreVersionLocalization | `whatsNew` |
/// | `promotional_text.txt` | AppStoreVersionLocalization | `promotionalText` |
/// | `support_url.txt` | AppStoreVersionLocalization | `supportUrl` |
/// | `marketing_url.txt` | AppStoreVersionLocalization | `marketingUrl` |
///
/// The fastlane layout hides this: one flat directory per locale, with
/// nothing to say that half of it is version-scoped and half is not. Google
/// Play's equivalent maps onto a single `Listing`.
///
/// ## Parameters
///
/// ### Required
/// - **[locale]**: The directory name, used verbatim as the App Store locale.
///
/// ### Optional
/// - **[name]**, **[subtitle]**, **[privacyUrl]**: app-wide fields.
/// - **[description]**, **[keywords]**, **[releaseNotes]**,
///   **[promotionalText]**, **[supportUrl]**, **[marketingUrl]**:
///   version-scoped fields.
@immutable
class FastlaneIosListing {
  /// Creates a listing read from disk.
  const FastlaneIosListing({
    required this.locale,
    this.name,
    this.subtitle,
    this.privacyUrl,
    this.description,
    this.keywords,
    this.releaseNotes,
    this.promotionalText,
    this.supportUrl,
    this.marketingUrl,
  });

  /// The directory name, used verbatim as the App Store locale.
  ///
  /// `colaxy_localization` already maps Flutter locales to Apple's spelling
  /// when it writes these directories (`ja-JP` becomes `ja`, `zh-TW` becomes
  /// `zh-Hant`), so no second table lives here.
  final String locale;

  /// Contents of `name.txt`. App-wide.
  final String? name;

  /// Contents of `subtitle.txt`. App-wide.
  final String? subtitle;

  /// Contents of `privacy_url.txt`. App-wide.
  final String? privacyUrl;

  /// Contents of `description.txt`. Version-scoped.
  final String? description;

  /// Contents of `keywords.txt`. Version-scoped.
  final String? keywords;

  /// Contents of `release_notes.txt`. Version-scoped.
  final String? releaseNotes;

  /// Contents of `promotional_text.txt`. Version-scoped.
  final String? promotionalText;

  /// Contents of `support_url.txt`. Version-scoped.
  final String? supportUrl;

  /// Contents of `marketing_url.txt`. Version-scoped.
  final String? marketingUrl;

  /// Whether the locale directory held nothing this package can publish.
  bool get isEmpty =>
      appInfoLocalization().isEmpty && versionLocalization().isEmpty;

  /// The app-wide half, for `AppInfoLocalizationsApi`.
  AppInfoLocalization appInfoLocalization() => AppInfoLocalization(
    locale: locale,
    name: name,
    subtitle: subtitle,
    privacyPolicyUrl: privacyUrl,
  );

  /// The version-scoped half, for `AppStoreVersionLocalizationsApi`.
  AppStoreVersionLocalization versionLocalization() =>
      AppStoreVersionLocalization(
        locale: locale,
        description: description,
        keywords: keywords,
        whatsNew: releaseNotes,
        promotionalText: promotionalText,
        supportUrl: supportUrl,
        marketingUrl: marketingUrl,
      );

  @override
  String toString() => 'FastlaneIosListing($locale)';
}
