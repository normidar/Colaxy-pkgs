import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/app_store/asset_uploader.dart';
import 'package:colaxy_store_publish/src/app_store/build_upload.dart';
import 'package:colaxy_store_publish/src/app_store/build_upload_file.dart';
import 'package:colaxy_store_publish/src/app_store/checksum_algorithm.dart';
import 'package:colaxy_store_publish/src/core/store_publish_exception.dart';
import 'package:path/path.dart' as p;

/// Delivering an app binary to App Store Connect.
///
/// **This is what made Transporter and `altool` unnecessary.** Until App
/// Store Connect API 4.1 there was no way to send a binary over the API, and
/// every plan in this repository was written around that limit. It is gone.
///
/// The sequence mirrors a screenshot upload, one level deeper:
///
/// ```text
/// POST  /v1/buildUploads          declare version and platform
/// POST  /v1/buildUploadFiles      reserve the archive; get upload operations
/// PUT   (Apple's asset host)      the bytes, chunked, no bearer token
/// PATCH /v1/buildUploadFiles/{id} commit with uploaded + checksums
/// GET   /v1/buildUploads/{id}     poll until COMPLETE or FAILED
/// ```
///
/// Two things differ from screenshots and are easy to get wrong:
///
/// - **The version is declared, not read.** Google Play takes the version
///   code out of the bundle; here `cfBundleVersion` is something you assert,
///   and asserting it wrongly is not caught by the file.
/// - **The commit takes a `Checksums` object naming an algorithm**, where a
///   screenshot takes a bare string.
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: An authenticated App Store Connect client.
/// - **`uploader`**: Sends the bytes.
/// - **[appId]**: The numeric app ID.
///
/// ### Optional
/// - **[onLog]**: Receives one line per step (default: `null`).
class BuildUploadsApi {
  /// Creates a build uploads client for one app.
  const BuildUploadsApi({
    required AppStoreConnectClient client,
    required AssetUploader uploader,
    required this.appId,
    this.onLog,
  }) : _client = client,
       _uploader = uploader;

  /// The numeric app ID.
  final String appId;

  /// Receives one line per step.
  final StoreConsoleLog? onLog;

  final AppStoreConnectClient _client;
  final AssetUploader _uploader;

  /// The app's build uploads, most recent first as Apple returns them.
  Future<List<BuildUpload>> list() async {
    final resources = await _client
        .resources('/v1/apps/$appId/buildUploads', query: {'limit': 200})
        .toList();
    return [for (final json in resources) BuildUpload.fromJson(json)];
  }

  /// Reads one upload back, for polling.
  Future<BuildUpload> get(String uploadId) async {
    final response = await _client.getJson('/v1/buildUploads/$uploadId');
    return BuildUpload.fromJson(
      response['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// Uploads [file] and waits for App Store Connect to accept it.
  ///
  /// Does the whole sequence. On any failure after the upload is created, the
  /// upload is deleted — a half-delivered build is worse than none, and
  /// `/v1/buildUploads/{id}` accepts `DELETE` precisely for this.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[file]**: The `.ipa` or `.pkg` to deliver.
  /// - **[cfBundleVersion]**: The build number, e.g. `412`. **Asserted, not
  ///   read from the file** — Apple takes this on trust.
  /// - **[cfBundleShortVersionString]**: The marketing version, e.g. `1.4.0`.
  ///
  /// ### Optional
  /// - **[platform]**: `IOS`, `MAC_OS`, `TV_OS` or `VISION_OS`
  ///   (default: `IOS`).
  /// - **[algorithm]**: Checksum algorithm (default: [ChecksumAlgorithm.md5]).
  ///   **`SHA_256` is in the specification's enum and is rejected by the
  ///   store.** Verified against a real account: committing with
  ///   `{file: {hash, algorithm: SHA_256}}` fails
  ///   `ENTITY_ERROR.ATTRIBUTE.INVALID`, while the same shape with `MD5` is
  ///   accepted. The parameter stays because the enum has two values; the
  ///   default is the one that works.
  /// - **[wait]**: Whether to poll until Apple finishes (default: `true`).
  /// - **[timeout]**: How long to poll for (default: 30 minutes).
  ///
  /// ## Example
  ///
  /// ```dart
  /// final upload = await api.upload(
  ///   file: File('build/ios/ipa/App.ipa'),
  ///   cfBundleVersion: '412',
  ///   cfBundleShortVersionString: '1.4.0',
  /// );
  /// ```
  Future<BuildUpload> upload({
    required File file,
    required String cfBundleVersion,
    required String cfBundleShortVersionString,
    String platform = 'IOS',
    ChecksumAlgorithm algorithm = ChecksumAlgorithm.md5,
    bool wait = true,
    Duration timeout = const Duration(minutes: 30),
    Duration interval = const Duration(seconds: 10),
    Future<void> Function(Duration)? sleep,
  }) async {
    if (!file.existsSync()) {
      throw FastlaneLayoutException(
        'No app binary to upload at this path.',
        path: file.path,
      );
    }
    final uti = BuildUploadUti.byExtension(p.extension(file.path));
    if (uti != BuildUploadUti.ipa && uti != BuildUploadUti.pkg) {
      throw FastlaneLayoutException(
        'App Store Connect takes an .ipa or a .pkg here; this file is '
        'neither by its suffix.',
        path: file.path,
      );
    }

    final upload = BuildUpload.fromJson(
      (await _client.postJson('/v1/buildUploads', {
            'data': {
              'type': 'buildUploads',
              'attributes': {
                'cfBundleVersion': cfBundleVersion,
                'cfBundleShortVersionString': cfBundleShortVersionString,
                'platform': platform,
              },
              // Required. The specification lists `app` under the request's
              // *relationships* `required`, separately from the attribute
              // list — omitting it fails with
              // `ENTITY_ERROR.RELATIONSHIP.REQUIRED`, which took a real
              // upload to discover.
              'relationships': {
                'app': {
                  'data': {'type': 'apps', 'id': appId},
                },
              },
            },
          }))['data']
          as Map<String, dynamic>? ??
          const {},
    );
    onLog?.call('created build upload ${upload.id} for $cfBundleVersion');

    try {
      await _sendArchive(upload.id, file, uti!, algorithm);
    } on Object {
      await _deleteQuietly(upload.id);
      rethrow;
    }

    if (!wait) return get(upload.id);
    return _awaitCompletion(
      upload.id,
      timeout: timeout,
      interval: interval,
      sleep: sleep,
    );
  }

  /// Abandons an upload.
  ///
  /// Worth calling on a run that failed partway: an upload left in
  /// `AWAITING_UPLOAD` is not a build, but it is clutter that nothing else
  /// clears.
  Future<void> delete(String uploadId) =>
      _client.delete('/v1/buildUploads/$uploadId');

  /// Reserves the archive, sends it, and commits it.
  Future<void> _sendArchive(
    String uploadId,
    File file,
    BuildUploadUti uti,
    ChecksumAlgorithm algorithm,
  ) async {
    final reserved = BuildUploadFile.fromJson(
      (await _client.postJson('/v1/buildUploadFiles', {
            'data': {
              'type': 'buildUploadFiles',
              'attributes': {
                'fileName': p.basename(file.path),
                'fileSize': file.lengthSync(),
                'uti': uti.wireName,
                'assetType': BuildUploadAssetType.asset.wireName,
              },
              'relationships': {
                'buildUpload': {
                  'data': {'type': 'buildUploads', 'id': uploadId},
                },
              },
            },
          }))['data']
          as Map<String, dynamic>? ??
          const {},
    );
    onLog?.call(
      'reserved ${p.basename(file.path)} '
      '(${reserved.uploadOperations.length} chunks)',
    );

    final checksum = await _uploader.upload(
      file,
      reserved.uploadOperations,
      algorithm: algorithm,
    );

    await _client.patchJson('/v1/buildUploadFiles/${reserved.id}', {
      'data': {
        'type': 'buildUploadFiles',
        'id': reserved.id,
        'attributes': {
          'uploaded': true,
          'sourceFileChecksums': {
            'file': {'hash': checksum, 'algorithm': algorithm.wireName},
          },
        },
      },
    });
    onLog?.call('committed the archive');
  }

  /// Polls until Apple finishes, and raises what it objected to.
  Future<BuildUpload> _awaitCompletion(
    String uploadId, {
    required Duration timeout,
    required Duration interval,
    Future<void> Function(Duration)? sleep,
  }) async {
    final rest = sleep ?? Future<void>.delayed;
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final upload = await get(uploadId);
      if (upload.hasFailed) {
        throw StoreApiException(
          'App Store Connect rejected the build: '
          '${upload.errors.join('; ')}',
          statusCode: 200,
          store: Store.appStore,
          detail:
              'Processing happens after the bytes arrive, so this is a late '
              'failure rather than a transfer problem.',
        );
      }
      if (upload.isComplete) {
        onLog?.call('build upload complete');
        return upload;
      }
      if (DateTime.now().isAfter(deadline)) return upload;
      await rest(interval);
    }
  }

  Future<void> _deleteQuietly(String uploadId) async {
    try {
      await delete(uploadId);
    } on StoreConsoleException {
      onLog?.call(
        'could not abandon build upload $uploadId; remove it by hand',
      );
    }
  }
}
