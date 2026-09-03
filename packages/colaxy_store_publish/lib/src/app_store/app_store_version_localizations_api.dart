import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/app_store_version_localization.dart';

/// The version-specific localized text of one App Store version.
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: An authenticated App Store Connect client.
/// - **[versionId]**: The version to read and write localizations of.
///
/// ## Example
///
/// ```dart
/// await api.update(
///   const AppStoreVersionLocalization(locale: 'ja', description: '…'),
/// );
/// ```
class AppStoreVersionLocalizationsApi {
  /// Creates a localizations client for one version.
  const AppStoreVersionLocalizationsApi({
    required AppStoreConnectClient client,
    required this.versionId,
  }) : _client = client;

  /// The version these localizations belong to.
  final String versionId;

  final AppStoreConnectClient _client;

  /// Every localization the version has.
  Future<List<AppStoreVersionLocalization>> list() async {
    final resources = await _client
        .resources(
          '/v1/appStoreVersions/$versionId/appStoreVersionLocalizations',
          query: {'limit': 200},
        )
        .toList();
    return [
      for (final json in resources)
        AppStoreVersionLocalization.fromJson(json),
    ];
  }

  /// The localization for [locale], or `null` if the version has none.
  Future<AppStoreVersionLocalization?> get(String locale) async {
    for (final localization in await list()) {
      if (localization.locale == locale) return localization;
    }
    return null;
  }

  /// Writes [localization], creating the locale if the version lacks it.
  ///
  /// Unlike Google Play's `listings.update`, this API's PATCH is a **partial**
  /// update: attributes that are not sent are left alone. So no merge against
  /// the store is needed here — omitting a field already means "leave it",
  /// which is exactly what a `null` on the model means.
  ///
  /// Creating is a separate verb on this API, so an absent locale is
  /// POSTed instead. The caller does not have to know which happened.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[localization]**: The text to write. Its `locale` names the target.
  Future<AppStoreVersionLocalization> update(
    AppStoreVersionLocalization localization,
  ) async {
    if (localization.locale.isEmpty) {
      throw ArgumentError.value(
        localization.locale,
        'localization.locale',
        'A localization needs a locale to be written to',
      );
    }

    final existing = localization.id ?? (await get(localization.locale))?.id;
    if (existing == null) return _create(localization);

    final response = await _client.patchJson(
      '/v1/appStoreVersionLocalizations/$existing',
      {
        'data': {
          'type': 'appStoreVersionLocalizations',
          'id': existing,
          'attributes': localization.toAttributes(),
        },
      },
    );
    return AppStoreVersionLocalization.fromJson(
      response['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// Removes a localization by its Apple identifier.
  ///
  /// Destructive and never called for you: a metadata directory that lacks a
  /// locale says nothing about whether the store should stop offering it.
  Future<void> delete(String id) =>
      _client.delete('/v1/appStoreVersionLocalizations/$id');

  Future<AppStoreVersionLocalization> _create(
    AppStoreVersionLocalization localization,
  ) async {
    final response = await _client.postJson(
      '/v1/appStoreVersionLocalizations',
      {
        'data': {
          'type': 'appStoreVersionLocalizations',
          'attributes': {
            'locale': localization.locale,
            ...localization.toAttributes(),
          },
          'relationships': {
            'appStoreVersion': {
              'data': {'type': 'appStoreVersions', 'id': versionId},
            },
          },
        },
      },
    );
    return AppStoreVersionLocalization.fromJson(
      response['data'] as Map<String, dynamic>? ?? const {},
    );
  }
}
