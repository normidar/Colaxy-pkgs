import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:test/test.dart';

import 'support.dart';

PlayPublisher _publisher(Recorder recorder) => PlayPublisher(
  api: publisherApi(recorder),
  packageName: 'com.example.app',
  guard: PlayApiGuard(retryPolicy: const RetryPolicy.none()),
);

/// Answers every call the doctor makes, for an app in a healthy state.
void _serveStore(
  Recorder recorder, {
  List<String> locales = const ['ja-JP'],
  List<String> tracks = const ['internal'],
}) => recorder.route((request) {
  final path = request.url.path;
  if (path.endsWith('/edits')) {
    return Recorder.ok({'id': 'edit-1', 'expiryTimeSeconds': '1787212800'});
  }
  if (path.endsWith('/listings')) {
    return Recorder.ok({
      'listings': [
        for (final locale in locales) {'language': locale, 'title': 'x'},
      ],
    });
  }
  if (path.endsWith('/tracks')) {
    return Recorder.ok({
      'tracks': [
        for (final track in tracks) {'track': track, 'releases': <dynamic>[]},
      ],
    });
  }
  return Recorder.ok(const <String, dynamic>{});
});

DoctorCheck _named(List<DoctorCheck> checks, String name) =>
    checks.firstWhere((check) => check.name == name);

void main() {
  late Directory android;

  tearDown(() {
    final temp = android.parent.parent.parent;
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  test('opening an edit is what proves edit permission', () async {
    // Reading a listing succeeds for an account that could never publish, so
    // the doctor has to attempt the write.
    android = buildMetadataTree({
      'ja-JP': {'title.txt': 'メモ'},
    });
    final recorder = Recorder();
    _serveStore(recorder);

    final checks = await PlayDoctor(
      publisher: _publisher(recorder),
      metadata: FastlaneMetadata(android),
    ).run();

    expect(_named(checks, 'Edit permission').outcome, DoctorOutcome.pass);
    expect(_named(checks, 'Edit permission').detail, contains('edit-1'));
  });

  test('reports the edit expiry Google returned', () async {
    android = buildMetadataTree({'ja-JP': {}});
    final recorder = Recorder();
    _serveStore(recorder);

    final checks = await PlayDoctor(publisher: _publisher(recorder)).run();

    expect(_named(checks, 'Edit permission').detail, contains('2026-08-20'));
  });

  test('always discards the edit it opened', () async {
    android = buildMetadataTree({'ja-JP': {}});
    final recorder = Recorder();
    _serveStore(recorder);

    final checks = await PlayDoctor(publisher: _publisher(recorder)).run();

    expect(_named(checks, 'Cleanup').outcome, DoctorOutcome.pass);
    expect(recorder.trace.last, startsWith('DELETE'));
    expect(
      recorder.trace.where((line) => line.endsWith(':commit')),
      isEmpty,
    );
  });

  test('a refused edit skips the rest rather than repeating one error',
      () async {
    android = buildMetadataTree({'ja-JP': {}});
    final recorder = Recorder()
      ..route(
        (request) => Recorder.error(apiError(403, 'forbidden'), status: 403),
      );

    final checks = await PlayDoctor(publisher: _publisher(recorder)).run();

    expect(_named(checks, 'Edit permission').outcome, DoctorOutcome.fail);
    expect(
      _named(checks, 'Edit permission').detail,
      contains('Users and permissions'),
    );
    expect(
      checks.skip(1).every((check) => check.outcome == DoctorOutcome.skip),
      isTrue,
    );
  });

  test('one failing surface does not stop the others', () async {
    // A tool that dies on the first failure leaves every other surface
    // unexamined, which is exactly when someone needs to see them.
    android = buildMetadataTree({'ja-JP': {}});
    final recorder = Recorder()
      ..route((request) {
        final path = request.url.path;
        if (path.endsWith('/edits')) return Recorder.ok({'id': 'edit-1'});
        if (path.endsWith('/tracks')) {
          return Recorder.error(apiError(500, 'boom'), status: 500);
        }
        return Recorder.ok(const <String, dynamic>{});
      });

    final checks = await PlayDoctor(publisher: _publisher(recorder)).run();

    expect(_named(checks, 'Release tracks').outcome, DoctorOutcome.fail);
    expect(_named(checks, 'Cleanup').outcome, DoctorOutcome.pass);
  });

  group('empty is not pass', () {
    test('an app with no listing reports empty', () async {
      android = buildMetadataTree({'ja-JP': {}});
      final recorder = Recorder();
      _serveStore(recorder, locales: const []);

      final checks = await PlayDoctor(publisher: _publisher(recorder)).run();

      expect(_named(checks, 'Store listings').outcome, DoctorOutcome.empty);
    });

    test('an app with no tracks reports empty', () async {
      android = buildMetadataTree({'ja-JP': {}});
      final recorder = Recorder();
      _serveStore(recorder, tracks: const []);

      final checks = await PlayDoctor(publisher: _publisher(recorder)).run();

      expect(_named(checks, 'Release tracks').outcome, DoctorOutcome.empty);
    });
  });

  group('local vs store locales', () {
    test('names locales that exist here and not on the store', () async {
      android = buildMetadataTree({
        'ja-JP': {'title.txt': 'メモ'},
        'de-DE': {'title.txt': 'Notiz'},
      });
      final recorder = Recorder();
      _serveStore(recorder);

      final checks = await PlayDoctor(
        publisher: _publisher(recorder),
        metadata: FastlaneMetadata(android),
      ).run();

      expect(
        _named(checks, 'Local vs store locales').detail,
        contains('new here: de-DE'),
      );
    });

    test('names locales the publish will leave alone', () async {
      // Translated in Play Console and never generated locally. Not an error:
      // a publish simply does not touch it.
      android = buildMetadataTree({
        'ja-JP': {'title.txt': 'メモ'},
      });
      final recorder = Recorder();
      _serveStore(recorder, locales: const ['ja-JP', 'ko-KR']);

      final checks = await PlayDoctor(
        publisher: _publisher(recorder),
        metadata: FastlaneMetadata(android),
      ).run();

      final check = _named(checks, 'Local vs store locales');
      expect(check.outcome, DoctorOutcome.pass);
      expect(check.detail, contains('store only: ko-KR'));
    });

    test('says so when the two match exactly', () async {
      android = buildMetadataTree({
        'ja-JP': {'title.txt': 'メモ'},
      });
      final recorder = Recorder();
      _serveStore(recorder);

      final checks = await PlayDoctor(
        publisher: _publisher(recorder),
        metadata: FastlaneMetadata(android),
      ).run();

      expect(
        _named(checks, 'Local vs store locales').detail,
        contains('matching the store exactly'),
      );
    });

    test('is skipped with no metadata directory to compare', () async {
      android = buildMetadataTree({'ja-JP': {}});
      final recorder = Recorder();
      _serveStore(recorder);

      final checks = await PlayDoctor(publisher: _publisher(recorder)).run();

      expect(
        _named(checks, 'Local vs store locales').outcome,
        DoctorOutcome.skip,
      );
    });

    test('a missing metadata directory fails only that check', () async {
      android = buildMetadataTree({'ja-JP': {}});
      final recorder = Recorder();
      _serveStore(recorder);

      final checks = await PlayDoctor(
        publisher: _publisher(recorder),
        metadata: FastlaneMetadata(Directory('${android.path}/nope')),
      ).run();

      expect(
        _named(checks, 'Local vs store locales').outcome,
        DoctorOutcome.fail,
      );
      expect(_named(checks, 'Edit permission').outcome, DoctorOutcome.pass);
    });
  });
}
