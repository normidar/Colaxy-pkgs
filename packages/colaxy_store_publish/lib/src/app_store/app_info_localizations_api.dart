import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/app_info_localization.dart';

/// The app-wide localized text hanging off one app info record.
///
/// The record has to be the editable one — see `AppInfosApi.editable`.
/// Writing through another is reported to succeed and change nothing.
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: An authenticated App Store Connect client.
/// - **[appInfoId]**: The app info record to read and write through.
///
/// ## Example
///
/// ```dart
/// await api.update(
///   const AppInfoLocalization(locale: 'ja', name: 'メモ帳'),
/// );
/// ```
class AppInfoLocalizationsApi {
  /// Creates a localizations client for one app info record.
  const AppInfoLocalizationsApi({
    required AppStoreConnectClient client,
    required this.appInfoId,
  }) : _client = client;

  /// The app info record these localizations belong to.
  final String appInfoId;

  final AppStoreConnectClient _client;

  /// Every localization the record has.
  Future<List<AppInfoLocalization>> list() async {
    final resources = await _client
        .resources(
          '/v1/appInfos/$appInfoId/appInfoLocalizations',
          query: {'limit': 200},
        )
        .toList();
    return [for (final json in resources) AppInfoLocalization.fromJson(json)];
  }

  /// The localization for [locale], or `null` if the record has none.
  Future<AppInfoLocalization?> get(String locale) async {
    for (final localization in await list()) {
      if (localization.locale == locale) return localization;
    }
    return null;
  }

  /// Writes [localization], creating the locale if the record lacks it.
  ///
  /// A partial update, as on the version side: unsent attributes are left
  /// alone.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[localization]**: The text to write. Its `locale` names the target.
  Future<AppInfoLocalization> update(AppInfoLocalization localization) async {
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
      '/v1/appInfoLocalizations/$existing',
      {
        'data': {
          'type': 'appInfoLocalizations',
          'id': existing,
          'attributes': localization.toAttributes(),
        },
      },
    );
    return AppInfoLocalization.fromJson(
      response['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<AppInfoLocalization> _create(
    AppInfoLocalization localization,
  ) async {
    final response = await _client.postJson('/v1/appInfoLocalizations', {
      'data': {
        'type': 'appInfoLocalizations',
        'attributes': {
          'locale': localization.locale,
          ...localization.toAttributes(),
        },
        'relationships': {
          'appInfo': {
            'data': {'type': 'appInfos', 'id': appInfoId},
          },
        },
      },
    });
    return AppInfoLocalization.fromJson(
      response['data'] as Map<String, dynamic>? ?? const {},
    );
  }
}
