import 'dart:io';

import 'package:colaxy_store_publish/src/core/store_publish_exception.dart';
import 'package:colaxy_store_publish/src/google_play/play_api_guard.dart';
import 'package:colaxy_store_publish/src/google_play/play_bundle.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:path/path.dart' as p;

/// The Android App Bundles inside one open edit.
///
/// This is the half of publishing that App Store Connect has no equivalent
/// for. Google Play takes the binary over the same API as everything else, so
/// an Android release needs no external tool at any step; Apple does not, and
/// this package does not pretend otherwise by offering an iOS mirror of this
/// class.
///
/// ## Parameters
///
/// ### Required
/// - **`api`**: An authenticated Android Publisher client.
/// - **[packageName]**: The app's application ID.
/// - **[editId]**: The open edit changes are staged in.
///
/// ### Optional
/// - **`guard`**: Retry and error translation (default: `PlayApiGuard()`).
class PlayBundlesApi {
  /// Creates a bundles client bound to one edit.
  PlayBundlesApi({
    required play.AndroidPublisherApi api,
    required this.packageName,
    required this.editId,
    PlayApiGuard? guard,
  }) : _api = api,
       _guard = guard ?? PlayApiGuard();

  /// The app's application ID.
  final String packageName;

  /// The open edit changes are staged in.
  final String editId;

  final play.AndroidPublisherApi _api;
  final PlayApiGuard _guard;

  /// Every bundle attached to the edit.
  Future<List<PlayBundle>> list() async {
    final response = await _guard.run(
      'bundles.list',
      () => _api.edits.bundles.list(packageName, editId),
    );
    return [
      for (final bundle in response.bundles ?? const <play.Bundle>[])
        PlayBundle.fromApi(bundle),
    ];
  }

  /// Uploads an `.aab` and attaches it to the edit.
  ///
  /// Uploading does not release anything. The bundle becomes available to
  /// `PlayTracksApi.release`, and an edit committed without a track update
  /// leaves it visible in Play Console and served to nobody.
  ///
  /// Sent as a resumable upload by default. Bundles are the largest thing
  /// this package transfers, and a resumable upload retries the failed chunk
  /// rather than the whole file — on a slow CI network that is the difference
  /// between a retry costing seconds and costing the entire transfer again.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[file]**: The `.aab` to upload.
  ///
  /// ### Optional
  /// - **[deviceTierConfigId]**: Device tier config to generate APKs with,
  ///   or `'LATEST'` for the most recently uploaded one (default: `null`).
  /// - **[resumable]**: Whether to use a resumable upload (default: `true`).
  ///
  /// ## Example
  ///
  /// ```dart
  /// final bundle = await session.bundles.upload(
  ///   File('build/app/outputs/bundle/release/app-release.aab'),
  /// );
  /// print('uploaded version code ${bundle.versionCode}');
  /// ```
  Future<PlayBundle> upload(
    File file, {
    String? deviceTierConfigId,
    bool resumable = true,
  }) async {
    if (!file.existsSync()) {
      throw FastlaneLayoutException(
        'No app bundle to upload at this path.',
        path: file.path,
      );
    }
    if (p.extension(file.path).toLowerCase() != '.aab') {
      throw FastlaneLayoutException(
        'This endpoint takes an Android App Bundle. Upload an APK through '
        'the apks resource instead.',
        path: file.path,
      );
    }

    final length = file.lengthSync();
    final response = await _guard.run(
      'bundles.upload (${p.basename(file.path)})',
      // Opened inside the closure so a retry re-reads the file: a stream
      // built once would already be drained on the second attempt.
      () => _api.edits.bundles.upload(
        packageName,
        editId,
        deviceTierConfigId: deviceTierConfigId,
        uploadOptions: resumable
            ? play.ResumableUploadOptions()
            : play.UploadOptions.defaultOptions,
        uploadMedia: play.Media(file.openRead(), length),
      ),
    );
    return PlayBundle.fromApi(response);
  }
}
