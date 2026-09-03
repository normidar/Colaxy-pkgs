import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:test/test.dart';

import 'support.dart';

Future<PlayEditSession> _open(
  Recorder recorder, {
  String id = 'edit-1',
  String? expiryTimeSeconds,
  PlayApiGuard? guard,
}) {
  recorder.enqueue({'id': id, 'expiryTimeSeconds': ?expiryTimeSeconds});
  return PlayEditSession.open(
    api: publisherApi(recorder),
    packageName: 'com.example.app',
    guard: guard ?? PlayApiGuard(retryPolicy: const RetryPolicy.none()),
  );
}

void main() {
  group('open', () {
    test('creates an edit and keeps its id', () async {
      final recorder = Recorder();

      final session = await _open(recorder);

      expect(session.editId, 'edit-1');
      expect(session.state, PlayEditState.open);
      expect(recorder.trace.single, endsWith('/com.example.app/edits'));
    });

    test('parses the expiry Google returns as seconds-since-epoch text', () {
      final recorder = Recorder();

      return _open(recorder, expiryTimeSeconds: '1787212800').then((session) {
        expect(session.expiresAt, DateTime.utc(2026, 8, 20, 8));
        expect(session.timeRemaining, isNotNull);
      });
    });

    test('leaves expiresAt null when Google sends no deadline', () async {
      final session = await _open(Recorder());

      expect(session.expiresAt, isNull);
      expect(session.timeRemaining, isNull);
    });

    test('fails rather than carrying an edit with no id', () {
      final recorder = Recorder()..enqueue(const <String, dynamic>{});

      expect(
        () => PlayEditSession.open(
          api: publisherApi(recorder),
          packageName: 'com.example.app',
        ),
        throwsA(isA<StoreApiException>()),
      );
    });
  });

  group('lifecycle', () {
    test('validate leaves the edit open and committable', () async {
      final recorder = Recorder();
      final session = await _open(recorder);

      await session.validate();

      expect(session.isOpen, isTrue);
      expect(recorder.trace.last, endsWith(':validate'));
    });

    test('commit spends the edit', () async {
      final recorder = Recorder();
      final session = await _open(recorder);

      await session.commit();

      expect(session.state, PlayEditState.committed);
      expect(recorder.trace.last, endsWith(':commit'));
    });

    test('discard spends the edit without committing', () async {
      final recorder = Recorder();
      final session = await _open(recorder);

      await session.discard();

      expect(session.state, PlayEditState.discarded);
      expect(recorder.trace.last, startsWith('DELETE'));
    });

    test('a second commit is refused locally, not sent', () async {
      final recorder = Recorder();
      final session = await _open(recorder);
      await session.commit();
      final sent = recorder.requests.length;

      expect(session.commit, throwsA(isA<StateError>()));
      expect(recorder.requests, hasLength(sent));
    });

    test('sends changesInReviewBehavior when asked', () async {
      final recorder = Recorder();
      final session = await _open(recorder);

      await session.commit(
        changesInReviewBehavior: ChangesInReviewBehavior.errorIfInReview,
      );

      expect(
        recorder.requests.last.url.queryParameters['changesInReviewBehavior'],
        'ERROR_IF_IN_REVIEW',
      );
    });

    test('omits changesInReviewBehavior when not asked', () async {
      final recorder = Recorder();
      final session = await _open(recorder);

      await session.commit();

      expect(
        recorder.requests.last.url.queryParameters,
        isNot(contains('changesInReviewBehavior')),
      );
    });

    test('omits changesNotSentForReview rather than sending false', () async {
      // Sending `false` explicitly is not the same as omitting it on every
      // Google endpoint, and omitting is what "no opinion" means.
      final recorder = Recorder();
      final session = await _open(recorder);

      await session.commit();

      expect(
        recorder.requests.last.url.queryParameters,
        isNot(contains('changesNotSentForReview')),
      );
    });
  });

  group('discardQuietly', () {
    test('swallows a failing discard so the real error survives', () async {
      final recorder = Recorder();
      final session = await _open(recorder);
      recorder.enqueue(apiError(500, 'boom'), status: 500);

      expect(await session.discardQuietly(), isFalse);
      expect(session.state, PlayEditState.discarded);
    });

    test('does nothing to an edit that is already spent', () async {
      final recorder = Recorder();
      final session = await _open(recorder);
      await session.commit();
      final sent = recorder.requests.length;

      expect(await session.discardQuietly(), isFalse);
      expect(recorder.requests, hasLength(sent));
    });
  });
}
