import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

PlayImagesApi _api(Recorder recorder) => PlayImagesApi(
  api: publisherApi(recorder),
  packageName: 'com.example.app',
  editId: 'edit-1',
  guard: PlayApiGuard(retryPolicy: const RetryPolicy.none()),
);

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('colaxy_publish_images');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  File image(String name) => File(p.join(temp.path, name))
    ..writeAsBytesSync(onePixelPng);

  group('upload', () {
    test('sends the file to the slot named by the image type', () async {
      final recorder = Recorder()
        ..enqueue({
          'image': {'id': 'img-1', 'sha256': 'abc'},
        });

      final uploaded = await _api(recorder).upload(
        language: 'ja-JP',
        imageType: PlayImageType.phoneScreenshots,
        file: image('01.png'),
      );

      expect(uploaded.id, 'img-1');
      expect(
        recorder.requests.single.url.path,
        endsWith('/listings/ja-JP/phoneScreenshots'),
      );
    });

    test('uses the upload endpoint, not the metadata one', () async {
      final recorder = Recorder()
        ..enqueue({
          'image': {'id': 'img-1'},
        });

      await _api(recorder).upload(
        language: 'ja-JP',
        imageType: PlayImageType.featureGraphic,
        file: image('featureGraphic.png'),
      );

      expect(recorder.requests.single.url.path, startsWith('/upload/'));
    });

    test('sends the AI attestation only when given one', () async {
      final recorder = Recorder()
        ..enqueue({
          'image': {'id': 'img-1'},
        })
        ..enqueue({
          'image': {'id': 'img-2'},
        });
      final api = _api(recorder);

      await api.upload(
        language: 'ja-JP',
        imageType: PlayImageType.icon,
        file: image('icon.png'),
      );
      await api.upload(
        language: 'ja-JP',
        imageType: PlayImageType.icon,
        file: image('icon.png'),
        aiGeneratedState: PlayAiGeneratedState.notAiGenerated,
      );

      expect(
        recorder.requests.first.url.queryParameters,
        isNot(contains('aiGeneratedState')),
      );
      expect(
        recorder.requests.last.url.queryParameters['aiGeneratedState'],
        'aiGeneratedStateNotAiGenerated',
      );
    });

    test('refuses a missing file before sending anything', () {
      final recorder = Recorder();

      expect(
        () => _api(recorder).upload(
          language: 'ja-JP',
          imageType: PlayImageType.phoneScreenshots,
          file: File(p.join(temp.path, 'nope.png')),
        ),
        throwsA(isA<FastlaneLayoutException>()),
      );
      expect(recorder.requests, isEmpty);
    });

    test('refuses a suffix that is neither PNG nor JPEG', () {
      // Uploading a WebP under the wrong content type fails with something
      // that names neither the file nor the type.
      final recorder = Recorder();
      final file = File(p.join(temp.path, 'shot.webp'))
        ..writeAsBytesSync(onePixelPng);

      expect(
        () => _api(recorder).upload(
          language: 'ja-JP',
          imageType: PlayImageType.phoneScreenshots,
          file: file,
        ),
        throwsA(isA<FastlaneLayoutException>()),
      );
      expect(recorder.requests, isEmpty);
    });

    test('does not judge dimensions or file size', () async {
      // A one-pixel PNG is not a legal screenshot. Google says so; this
      // package does not, because a local rulebook goes stale and starts
      // rejecting what the store would have taken.
      final recorder = Recorder()
        ..enqueue({
          'image': {'id': 'img-1'},
        });

      await _api(recorder).upload(
        language: 'ja-JP',
        imageType: PlayImageType.phoneScreenshots,
        file: image('tiny.png'),
      );

      expect(recorder.requests, hasLength(1));
    });
  });

  group('deleteAll', () {
    test('answers how many images were removed', () async {
      final recorder = Recorder()
        ..enqueue({
          'deleted': [
            {'id': 'img-1'},
            {'id': 'img-2'},
          ],
        });

      final removed = await _api(recorder).deleteAll(
        language: 'ja-JP',
        imageType: PlayImageType.phoneScreenshots,
      );

      expect(removed, 2);
      expect(recorder.requests.single.method, 'DELETE');
    });

    test('answers zero for a slot that held nothing', () async {
      final recorder = Recorder()..enqueue(const <String, dynamic>{});

      expect(
        await _api(recorder).deleteAll(
          language: 'ja-JP',
          imageType: PlayImageType.tvScreenshots,
        ),
        0,
      );
    });
  });

  group('list', () {
    test('maps the images already in a slot', () async {
      final recorder = Recorder()
        ..enqueue({
          'images': [
            {'id': 'img-1', 'sha256': 'abc'},
          ],
        });

      final images = await _api(recorder).list(
        language: 'ja-JP',
        imageType: PlayImageType.phoneScreenshots,
      );

      expect(images.single.sha256, 'abc');
    });
  });
}
