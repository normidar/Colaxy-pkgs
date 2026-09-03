import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/src/core/store_publish_exception.dart';
import 'package:colaxy_store_publish/src/google_play/play_ai_generated_state.dart';
import 'package:colaxy_store_publish/src/google_play/play_api_guard.dart';
import 'package:colaxy_store_publish/src/google_play/play_image.dart';
import 'package:colaxy_store_publish/src/google_play/play_image_type.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:path/path.dart' as p;

/// The screenshots and graphics inside one open edit.
///
/// Nothing here checks an image's dimensions, aspect ratio, file size, or how
/// many of a kind a listing needs. Google publishes some of those rules and
/// enforces all of them, and a local copy would be a second, staler
/// rulebook — one that rejects combinations the store would have accepted.
/// Invalid images fail at [upload] with Google's own message.
///
/// What is checked locally is only what makes the request impossible to
/// build: a file that is not there, and a suffix that is neither PNG nor
/// JPEG, which would otherwise be uploaded under a wrong content type and
/// fail with something unrelated.
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
class PlayImagesApi {
  /// Creates an images client bound to one edit.
  PlayImagesApi({
    required play.AndroidPublisherApi api,
    required this.packageName,
    required this.editId,
    PlayApiGuard? guard,
  }) : _api = api,
       _guard = guard ?? PlayApiGuard();

  /// Content types Google Play accepts for listing images.
  static const _contentTypes = {
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
  };

  /// The app's application ID.
  final String packageName;

  /// The open edit changes are staged in.
  final String editId;

  final play.AndroidPublisherApi _api;
  final PlayApiGuard _guard;

  /// The images already in one slot.
  ///
  /// Answers an empty list, not an error, for a slot that holds nothing.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[language]**: The locale, as Google Play spells it.
  /// - **[imageType]**: Which slot to read.
  Future<List<PlayImage>> list({
    required String language,
    required PlayImageType imageType,
  }) async {
    final response = await _guard.run(
      'images.list ($language/${imageType.wireName})',
      () => _api.edits.images.list(
        packageName,
        editId,
        language,
        imageType.wireName,
      ),
    );
    return [
      for (final image in response.images ?? const <play.Image>[])
        PlayImage.fromApi(image),
    ];
  }

  /// Adds [file] to one slot.
  ///
  /// For the slots that hold a set — screenshots — this appends, so
  /// publishing a new set over an old one leaves both unless [deleteAll] runs
  /// first. For the single-image slots — icon, feature graphic, TV banner —
  /// Google replaces what is there.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[language]**: The locale, as Google Play spells it.
  /// - **[imageType]**: Which slot to add to.
  /// - **[file]**: The PNG or JPEG to upload.
  ///
  /// ### Optional
  /// - **[aiGeneratedState]**: The developer's attestation about how the
  ///   image was made (default: `null`, sending no attestation).
  ///
  /// ## Example
  ///
  /// ```dart
  /// await session.images.upload(
  ///   language: 'ja-JP',
  ///   imageType: PlayImageType.phoneScreenshots,
  ///   file: File('.../images/phoneScreenshots/01.png'),
  /// );
  /// ```
  Future<PlayImage> upload({
    required String language,
    required PlayImageType imageType,
    required File file,
    PlayAiGeneratedState? aiGeneratedState,
  }) async {
    if (!file.existsSync()) {
      throw FastlaneLayoutException(
        'No image to upload at this path.',
        path: file.path,
      );
    }
    final contentType = _contentTypes[p.extension(file.path).toLowerCase()];
    if (contentType == null) {
      throw FastlaneLayoutException(
        'Google Play takes PNG and JPEG listing images; this file is neither '
        'by its suffix.',
        path: file.path,
      );
    }

    final length = file.lengthSync();
    final response = await _guard.run(
      'images.upload ($language/${imageType.wireName}/'
      '${p.basename(file.path)})',
      // The stream is opened inside the closure so a retry reads the file
      // from the start again. A stream created once would be already drained
      // on the second attempt, and the retry would upload nothing.
      () => _api.edits.images.upload(
        packageName,
        editId,
        language,
        imageType.wireName,
        aiGeneratedState: aiGeneratedState?.wireName,
        uploadMedia: play.Media(
          file.openRead(),
          length,
          contentType: contentType,
        ),
      ),
    );

    final image = response.image;
    if (image == null) {
      throw const StoreApiException(
        'Google Play accepted the image but described none in its response.',
        statusCode: 200,
        store: Store.googlePlay,
      );
    }
    return PlayImage.fromApi(image);
  }

  /// Removes one image by its Google-assigned id.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[language]**: The locale, as Google Play spells it.
  /// - **[imageType]**: Which slot the image is in.
  /// - **[imageId]**: The id from [list] or [upload].
  Future<void> delete({
    required String language,
    required PlayImageType imageType,
    required String imageId,
  }) => _guard.run(
    'images.delete ($language/${imageType.wireName}/$imageId)',
    () => _api.edits.images.delete(
      packageName,
      editId,
      language,
      imageType.wireName,
      imageId,
    ),
  );

  /// Empties one slot, and answers how many images it held.
  ///
  /// This is the destructive half of replacing a screenshot set, and is
  /// deliberately not called by the publisher unless asked: uploads append,
  /// so a run that skips it adds to what is there rather than damaging it.
  /// Losing a set is unrecoverable from the local side if the store held
  /// screenshots that were never generated locally.
  ///
  /// ## Parameters
  ///
  /// ### Required
  /// - **[language]**: The locale, as Google Play spells it.
  /// - **[imageType]**: Which slot to empty.
  Future<int> deleteAll({
    required String language,
    required PlayImageType imageType,
  }) async {
    final response = await _guard.run(
      'images.deleteall ($language/${imageType.wireName})',
      () => _api.edits.images.deleteall(
        packageName,
        editId,
        language,
        imageType.wireName,
      ),
    );
    return response.deleted?.length ?? 0;
  }
}
