import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

PlayPublisher _publisher(Recorder recorder) => PlayPublisher(
  api: publisherApi(recorder),
  packageName: 'com.example.app',
  guard: PlayApiGuard(retryPolicy: const RetryPolicy.none()),
);

void _serveEdits(Recorder recorder) => recorder.route((request) {
  if (request.url.path.endsWith('/edits')) {
    return Recorder.ok({'id': 'edit-1'});
  }
  return Recorder.ok(const <String, dynamic>{});
});

void main() {
  group('edit', () {
    test('commits when the body returns', () async {
      final recorder = Recorder();
      _serveEdits(recorder);

      final result = await _publisher(recorder).edit((session) async => 42);

      expect(result, 42);
      expect(recorder.trace.last, endsWith(':commit'));
    });

    test('discards and rethrows when the body throws', () async {
      // An edit abandoned by a crashed job is what makes the *next* run fail,
      // with an error naming nothing about this one.
      final recorder = Recorder();
      _serveEdits(recorder);

      await expectLater(
        _publisher(recorder).edit<void>(
          (session) async => throw StateError('build failed'),
        ),
        throwsA(isA<StateError>()),
      );
      expect(recorder.trace.last, startsWith('DELETE'));
      expect(
        recorder.trace.where((line) => line.endsWith(':commit')),
        isEmpty,
      );
    });

    test('a dry run validates and then discards', () async {
      final recorder = Recorder();
      _serveEdits(recorder);

      await _publisher(recorder).edit<void>(
        (session) async {},
        dryRun: true,
      );

      expect(
        recorder.trace.where((line) => line.endsWith(':validate')),
        hasLength(1),
      );
      expect(
        recorder.trace.where((line) => line.endsWith(':commit')),
        isEmpty,
      );
      expect(recorder.trace.last, startsWith('DELETE'));
    });

    test('a failing commit leaves no edit behind', () async {
      final recorder = Recorder()
        ..route((request) {
          if (request.url.path.endsWith('/edits')) {
            return Recorder.ok({'id': 'edit-1'});
          }
          if (request.url.path.endsWith(':commit')) {
            return Recorder.error(apiError(409, 'stale'), status: 409);
          }
          return Recorder.ok(const <String, dynamic>{});
        });

      await expectLater(
        _publisher(recorder).edit<void>((session) async {}),
        throwsA(isA<PlayEditConflictException>()),
      );
      expect(recorder.trace.last, startsWith('DELETE'));
    });
  });

  group('bundles', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('colaxy_publish_bundle');
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('uploads an aab and reports the version code Google read', () async {
      final recorder = Recorder()..enqueue({'versionCode': 412, 'sha256': 'a'});
      final file = File(p.join(temp.path, 'app-release.aab'))
        ..writeAsBytesSync(List.filled(64, 0));
      final api = PlayBundlesApi(
        api: publisherApi(recorder),
        packageName: 'com.example.app',
        editId: 'edit-1',
        guard: PlayApiGuard(retryPolicy: const RetryPolicy.none()),
      );

      final bundle = await api.upload(file, resumable: false);

      expect(bundle.versionCode, 412);
      expect(recorder.requests.single.url.path, startsWith('/upload/'));
    });

    test('refuses an apk, which needs a different endpoint', () {
      final recorder = Recorder();
      final file = File(p.join(temp.path, 'app-release.apk'))
        ..writeAsBytesSync(List.filled(8, 0));
      final api = PlayBundlesApi(
        api: publisherApi(recorder),
        packageName: 'com.example.app',
        editId: 'edit-1',
      );

      expect(
        () => api.upload(file),
        throwsA(isA<FastlaneLayoutException>()),
      );
      expect(recorder.requests, isEmpty);
    });

    test('refuses a missing file before opening a stream', () {
      final recorder = Recorder();
      final api = PlayBundlesApi(
        api: publisherApi(recorder),
        packageName: 'com.example.app',
        editId: 'edit-1',
      );

      expect(
        () => api.upload(File(p.join(temp.path, 'nope.aab'))),
        throwsA(isA<FastlaneLayoutException>()),
      );
      expect(recorder.requests, isEmpty);
    });
  });
}
