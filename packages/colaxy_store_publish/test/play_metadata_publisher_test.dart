import 'dart:convert';
import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'support.dart';

/// Answers every Play call a publish makes, so tests script only the shape of
/// the store, not the order of the requests.
void _serveStore(Recorder recorder, {List<String> existingLocales = const []}) {
  recorder.route((request) {
    final path = request.url.path;
    if (path.endsWith('/edits')) {
      return Recorder.ok({'id': 'edit-1'});
    }
    if (path.endsWith('/listings') && request.method == 'GET') {
      return Recorder.ok({
        'listings': [
          for (final locale in existingLocales)
            {'language': locale, 'fullDescription': 'store copy'},
        ],
      });
    }
    if (path.startsWith('/upload/')) {
      return Recorder.ok({
        'image': {'id': 'img-1'},
      });
    }
    if (request.method == 'DELETE') {
      return Recorder.ok({
        'deleted': [
          {'id': 'old-1'},
          {'id': 'old-2'},
        ],
      });
    }
    return Recorder.ok(const <String, dynamic>{});
  });
}

Future<PlayEditSession> _session(Recorder recorder) => PlayEditSession.open(
  api: publisherApi(recorder),
  packageName: 'com.example.app',
  guard: PlayApiGuard(retryPolicy: const RetryPolicy.none()),
);

List<http.Request> _uploads(Recorder recorder) => [
  for (final request in recorder.requests)
    if (request.url.path.startsWith('/upload/')) request,
];

void main() {
  late Directory android;

  tearDown(() {
    final temp = android.parent.parent.parent;
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  test('stages listings and screenshots for every locale found', () async {
    android = buildMetadataTree({
      'ja-JP': {
        'title.txt': 'メモ',
        'images/phoneScreenshots/01.png': '',
        'images/phoneScreenshots/02.png': '',
      },
      'en-US': {'title.txt': 'Notes'},
    });
    final recorder = Recorder();
    _serveStore(recorder);

    final report = await PlayMetadataPublisher(
      metadata: FastlaneMetadata(android),
    ).publish(await _session(recorder));

    expect(report.updatedLocales, ['en-US', 'ja-JP']);
    expect(report.imageCount, 2);
    expect(report.isEmpty, isFalse);
  });

  test('merges against the store so a partial locale clears nothing',
      () async {
    // `listings.update` replaces the whole listing. A locale directory with
    // only title.txt must not blank the description already on the store.
    android = buildMetadataTree({
      'ja-JP': {'title.txt': 'メモ'},
    });
    final recorder = Recorder();
    _serveStore(recorder, existingLocales: ['ja-JP']);

    await PlayMetadataPublisher(
      metadata: FastlaneMetadata(android),
    ).publish(await _session(recorder));

    final update = recorder.requests.lastWhere(
      (request) => request.url.path.endsWith('/listings/ja-JP'),
    );
    final sent = jsonDecode(update.body) as Map<String, dynamic>;
    expect(sent['title'], 'メモ');
    expect(sent['fullDescription'], 'store copy');
  });

  test('reads the store listings once, not once per locale', () async {
    android = buildMetadataTree({
      'ja-JP': {'title.txt': 'メモ'},
      'en-US': {'title.txt': 'Notes'},
      'ko-KR': {'title.txt': '메모'},
    });
    final recorder = Recorder();
    _serveStore(recorder);

    await PlayMetadataPublisher(
      metadata: FastlaneMetadata(android),
    ).publish(await _session(recorder));

    final reads = recorder.requests.where(
      (request) =>
          request.method == 'GET' && request.url.path.endsWith('/listings'),
    );
    expect(reads, hasLength(1));
  });

  test('appends screenshots by default, deleting nothing', () async {
    android = buildMetadataTree({
      'ja-JP': {'images/phoneScreenshots/01.png': ''},
    });
    final recorder = Recorder();
    _serveStore(recorder);

    final report = await PlayMetadataPublisher(
      metadata: FastlaneMetadata(android),
    ).publish(await _session(recorder));

    expect(report.deletedImageCount, 0);
    expect(
      recorder.requests.where((request) => request.method == 'DELETE'),
      isEmpty,
    );
  });

  test('empties a screenshot slot first when replacing is asked for',
      () async {
    android = buildMetadataTree({
      'ja-JP': {'images/phoneScreenshots/01.png': ''},
    });
    final recorder = Recorder();
    _serveStore(recorder);

    final report = await PlayMetadataPublisher(
      metadata: FastlaneMetadata(android),
      options: const PlayPublishOptions(replaceScreenshots: true),
    ).publish(await _session(recorder));

    expect(report.deletedImageCount, 2);
  });

  test('never empties a single-image slot, which upload replaces anyway',
      () async {
    android = buildMetadataTree({
      'ja-JP': {'images/featureGraphic.png': ''},
    });
    final recorder = Recorder();
    _serveStore(recorder);

    final report = await PlayMetadataPublisher(
      metadata: FastlaneMetadata(android),
      options: const PlayPublishOptions(replaceScreenshots: true),
    ).publish(await _session(recorder));

    expect(report.deletedImageCount, 0);
    expect(report.imageCount, 1);
  });

  test('leaves the stray feature graphic alone by default', () async {
    android = buildMetadataTree(
      {
        'ja-JP': {'title.txt': 'メモ'},
      },
      root: {'featureGraphic.png': ''},
    );
    final recorder = Recorder();
    _serveStore(recorder);

    final report = await PlayMetadataPublisher(
      metadata: FastlaneMetadata(android),
    ).publish(await _session(recorder));

    expect(report.imageCount, 0);
    expect(_uploads(recorder), isEmpty);
  });

  test('sends the stray feature graphic to each locale when asked', () async {
    android = buildMetadataTree(
      {
        'ja-JP': {'title.txt': 'メモ'},
        'en-US': {'title.txt': 'Notes'},
      },
      root: {'featureGraphic.png': ''},
    );
    final recorder = Recorder();
    _serveStore(recorder);

    final report = await PlayMetadataPublisher(
      metadata: FastlaneMetadata(android),
      options: const PlayPublishOptions(uploadStrayFeatureGraphic: true),
    ).publish(await _session(recorder));

    expect(report.imageCount, 2);
    expect(_uploads(recorder), hasLength(2));
  });

  test('prefers a per-locale feature graphic over the stray one', () async {
    android = buildMetadataTree(
      {
        'ja-JP': {'images/featureGraphic.png': ''},
      },
      root: {'featureGraphic.png': ''},
    );
    final recorder = Recorder();
    _serveStore(recorder);

    final report = await PlayMetadataPublisher(
      metadata: FastlaneMetadata(android),
      options: const PlayPublishOptions(uploadStrayFeatureGraphic: true),
    ).publish(await _session(recorder));

    expect(report.imageCount, 1);
  });

  test('reports a locale asked for and not present as skipped', () async {
    android = buildMetadataTree({
      'ja-JP': {'title.txt': 'メモ'},
    });
    final recorder = Recorder();
    _serveStore(recorder);

    final report = await PlayMetadataPublisher(
      metadata: FastlaneMetadata(android),
      options: const PlayPublishOptions(locales: {'ja-JP', 'de-DE'}),
    ).publish(await _session(recorder));

    expect(report.updatedLocales, ['ja-JP']);
    expect(report.skippedLocales, ['de-DE']);
  });

  test('a run that stages nothing reports itself as empty', () async {
    // Committing an empty edit still cancels a review in progress under
    // Google's default behaviour, so "nothing to do" has to be visible.
    android = buildMetadataTree({
      'ja-JP': {'changelogs/default.txt': '不具合の修正'},
    });
    final recorder = Recorder();
    _serveStore(recorder);

    final report = await PlayMetadataPublisher(
      metadata: FastlaneMetadata(android),
    ).publish(await _session(recorder));

    expect(report.isEmpty, isTrue);
    expect(report.skippedLocales, ['ja-JP']);
  });

  test('publishes nothing at all when both switches are off', () async {
    android = buildMetadataTree({
      'ja-JP': {
        'title.txt': 'メモ',
        'images/phoneScreenshots/01.png': '',
      },
    });
    final recorder = Recorder();
    _serveStore(recorder);
    final session = await _session(recorder);
    final before = recorder.requests.length;

    final report = await PlayMetadataPublisher(
      metadata: FastlaneMetadata(android),
      options: const PlayPublishOptions(
        publishListings: false,
        publishImages: false,
      ),
    ).publish(session);

    expect(report.isEmpty, isTrue);
    expect(recorder.requests, hasLength(before));
  });

  test('refuses to publish into an edit that is already spent', () async {
    android = buildMetadataTree({
      'ja-JP': {'title.txt': 'メモ'},
    });
    final recorder = Recorder();
    _serveStore(recorder);
    final session = await _session(recorder);
    await session.commit();

    expect(
      () => PlayMetadataPublisher(
        metadata: FastlaneMetadata(android),
      ).publish(session),
      throwsA(isA<StateError>()),
    );
  });

  test('does not commit — that stays with the caller', () async {
    android = buildMetadataTree({
      'ja-JP': {'title.txt': 'メモ'},
    });
    final recorder = Recorder();
    _serveStore(recorder);
    final session = await _session(recorder);

    await PlayMetadataPublisher(
      metadata: FastlaneMetadata(android),
    ).publish(session);

    expect(session.isOpen, isTrue);
    expect(
      recorder.trace.where((line) => line.endsWith(':commit')),
      isEmpty,
    );
  });
}
