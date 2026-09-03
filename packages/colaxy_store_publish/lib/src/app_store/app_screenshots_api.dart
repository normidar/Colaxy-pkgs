import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/app_screenshot.dart';
import 'package:colaxy_store_publish/src/app_store/app_screenshot_set.dart';
import 'package:colaxy_store_publish/src/app_store/asset_uploader.dart';
import 'package:colaxy_store_publish/src/app_store/screenshot_display_type.dart';
import 'package:colaxy_store_publish/src/core/store_publish_exception.dart';
import 'package:path/path.dart' as p;

/// Screenshots on one App Store version localization.
///
/// The full chain to a screenshot on Apple is **version → localization → set
/// → screenshot**, where Google Play reaches the equivalent in one call. This
/// class covers the last two links.
///
/// Uploading is three steps and cannot be collapsed:
///
/// 1. `POST /v1/appScreenshots` reserves the asset, answering upload
///    operations that point at another host.
/// 2. The bytes go to that host, chunk by chunk, without the API's token.
/// 3. `PATCH /v1/appScreenshots/{id}` commits with `uploaded: true` and the
///    file's MD5.
///
/// [upload] does all three. Apple then processes the asset **asynchronously**,
/// so a screenshot that uploaded cleanly can still fail minutes later — see
/// [awaitProcessing].
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: An authenticated App Store Connect client.
/// - **`uploader`**: Sends the bytes.
///
/// ### Optional
/// - **[onLog]**: Receives one line per step (default: `null`).
class AppScreenshotsApi {
  /// Creates a screenshots client.
  const AppScreenshotsApi({
    required AppStoreConnectClient client,
    required AssetUploader uploader,
    this.onLog,
  }) : _client = client,
       _uploader = uploader;

  /// Receives one line per step.
  final StoreConsoleLog? onLog;

  final AppStoreConnectClient _client;
  final AssetUploader _uploader;

  /// The screenshot sets on one version localization.
  Future<List<AppScreenshotSet>> sets(String localizationId) async {
    final resources = await _client
        .resources(
          '/v1/appStoreVersionLocalizations/$localizationId'
          '/appScreenshotSets',
          query: {'limit': 200},
        )
        .toList();
    return [for (final json in resources) AppScreenshotSet.fromJson(json)];
  }

  /// The set for [displayType] on [localizationId], creating it if absent.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[localizationId]**: The version localization the set hangs off.
  /// - **[displayType]**: Which device slot.
  Future<AppScreenshotSet> ensureSet({
    required String localizationId,
    required ScreenshotDisplayType displayType,
  }) async {
    for (final set in await sets(localizationId)) {
      if (set.displayType == displayType) return set;
    }
    final response = await _client.postJson('/v1/appScreenshotSets', {
      'data': {
        'type': 'appScreenshotSets',
        'attributes': {'screenshotDisplayType': displayType.wireName},
        'relationships': {
          'appStoreVersionLocalization': {
            'data': {
              'type': 'appStoreVersionLocalizations',
              'id': localizationId,
            },
          },
        },
      },
    });
    return AppScreenshotSet.fromJson(
      response['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// The screenshots already in one set.
  Future<List<AppScreenshot>> list(String setId) async {
    final resources = await _client
        .resources(
          '/v1/appScreenshotSets/$setId/appScreenshots',
          query: {'limit': 200},
        )
        .toList();
    return [for (final json in resources) AppScreenshot.fromJson(json)];
  }

  /// Reserves, uploads and commits [file] into [setId].
  ///
  /// The whole three-step dance. On any failure after the reservation is
  /// made, the reservation is deleted — an uncommitted screenshot shows in
  /// App Store Connect as a grey placeholder and blocks submission, which is
  /// a worse outcome than the upload simply having failed.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[setId]**: The set to add to.
  /// - **[file]**: The PNG or JPEG to upload.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final shot = await api.upload(setId: set.id, file: File('01.png'));
  /// ```
  Future<AppScreenshot> upload({
    required String setId,
    required File file,
  }) async {
    if (!file.existsSync()) {
      throw FastlaneLayoutException(
        'No screenshot to upload at this path.',
        path: file.path,
      );
    }
    final name = p.basename(file.path);
    final size = file.lengthSync();

    final reserved = AppScreenshot.fromJson(
      (await _client.postJson('/v1/appScreenshots', {
            'data': {
              'type': 'appScreenshots',
              'attributes': {'fileName': name, 'fileSize': size},
              'relationships': {
                'appScreenshotSet': {
                  'data': {'type': 'appScreenshotSets', 'id': setId},
                },
              },
            },
          }))['data']
          as Map<String, dynamic>? ??
          const {},
    );
    onLog?.call(
      'reserved $name (${reserved.uploadOperations.length} chunks)',
    );

    try {
      final checksum = await _uploader.upload(file, reserved.uploadOperations);
      final committed = AppScreenshot.fromJson(
        (await _client.patchJson('/v1/appScreenshots/${reserved.id}', {
              'data': {
                'type': 'appScreenshots',
                'id': reserved.id,
                'attributes': {
                  'uploaded': true,
                  'sourceFileChecksum': checksum,
                },
              },
            }))['data']
            as Map<String, dynamic>? ??
            const {},
      );
      onLog?.call('committed $name');
      return committed;
    } on Object {
      // An uncommitted reservation is worse than no reservation: it shows as
      // a grey placeholder and blocks submission until someone removes it.
      await _deleteQuietly(reserved.id);
      rethrow;
    }
  }

  /// Removes one screenshot.
  Future<void> delete(String id) => _client.delete('/v1/appScreenshots/$id');

  /// Empties a set by deleting every screenshot in it.
  ///
  /// Apple has no bulk delete and **`appScreenshotSets` has no `PATCH`**, so
  /// replacing a set means removing its members one at a time. Destructive,
  /// and never called unless asked.
  ///
  /// Answers how many were removed.
  Future<int> deleteAll(String setId) async {
    final existing = await list(setId);
    for (final screenshot in existing) {
      await delete(screenshot.id);
    }
    if (existing.isNotEmpty) {
      onLog?.call('emptied set $setId (${existing.length} screenshots)');
    }
    return existing.length;
  }

  /// Polls [id] until Apple finishes processing it, or [timeout] passes.
  ///
  /// Processing is asynchronous and can reject an asset that uploaded
  /// cleanly. Submitting before it settles produces "there are still
  /// screenshot uploads in progress", which names neither the screenshot nor
  /// the reason — so this exists to make the wait explicit.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[id]**: The screenshot to wait on.
  ///
  /// ### Optional
  /// - **[timeout]**: How long to wait (default: 2 minutes).
  /// - **[interval]**: How often to poll (default: 3 seconds).
  Future<AppScreenshot> awaitProcessing(
    String id, {
    Duration timeout = const Duration(minutes: 2),
    Duration interval = const Duration(seconds: 3),
    Future<void> Function(Duration)? sleep,
  }) async {
    final wait = sleep ?? Future<void>.delayed;
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final response = await _client.getJson('/v1/appScreenshots/$id');
      final screenshot = AppScreenshot.fromJson(
        response['data'] as Map<String, dynamic>? ?? const {},
      );
      if (screenshot.hasFailed) {
        throw StoreApiException(
          'App Store Connect rejected the screenshot: '
          '${screenshot.deliveryErrors.join('; ')}',
          statusCode: 200,
          store: Store.appStore,
          detail:
              'Processing happens after the upload succeeds, so this is a '
              'late failure rather than a transfer problem.',
        );
      }
      if (screenshot.isComplete) return screenshot;
      if (DateTime.now().isAfter(deadline)) return screenshot;
      await wait(interval);
    }
  }

  Future<void> _deleteQuietly(String id) async {
    try {
      await delete(id);
    } on StoreConsoleException {
      onLog?.call('could not remove the reservation $id; remove it by hand');
    }
  }
}
