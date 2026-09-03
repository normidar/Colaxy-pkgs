import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('retries', () {
    test('retries a 503 and returns the eventual success', () async {
      final waits = <Duration>[];
      final recorder = Recorder()
        ..enqueue(apiError(503, 'backend error'), status: 503)
        ..enqueue({'id': 'edit-1'});
      final guard = PlayApiGuard(
        sleep: (duration) async => waits.add(duration),
      );

      final session = await PlayEditSession.open(
        api: publisherApi(recorder),
        packageName: 'com.example.app',
        guard: guard,
      );

      expect(session.editId, 'edit-1');
      expect(waits, hasLength(1));
    });

    test('stops after maxAttempts instead of looping on a quota error',
        () async {
      // Play reports quota as 403, which the retry policy would not retry on
      // status alone — so the decision follows the translated type. That path
      // bypasses the policy's own attempt bound, and without a second bound
      // this call never returns.
      final waits = <Duration>[];
      final recorder = Recorder()
        ..route(
          (request) => Recorder.error(
            apiError(403, 'quota exceeded', reason: 'quotaExceeded'),
            status: 403,
          ),
        );
      final guard = PlayApiGuard(
        retryPolicy: const RetryPolicy(maxAttempts: 4),
        sleep: (duration) async => waits.add(duration),
      );

      await expectLater(
        PlayEditSession.open(
          api: publisherApi(recorder),
          packageName: 'com.example.app',
          guard: guard,
        ),
        throwsA(isA<StoreRateLimitException>()),
      );
      expect(recorder.requests, hasLength(4));
      expect(waits, hasLength(3));
    });

    test('never retries a conflicting edit', () async {
      final waits = <Duration>[];
      final recorder = Recorder()..enqueue({'id': 'edit-1'});
      final guard = PlayApiGuard(
        sleep: (duration) async => waits.add(duration),
      );
      final session = await PlayEditSession.open(
        api: publisherApi(recorder),
        packageName: 'com.example.app',
        guard: guard,
      );
      recorder.enqueue(apiError(409, 'edit is stale'), status: 409);

      await expectLater(
        session.commit,
        throwsA(isA<PlayEditConflictException>()),
      );
      expect(waits, isEmpty, reason: 'replaying a stale commit fails alike');
    });
  });

  group('translate', () {
    test('reads a 403 quota failure as rate limiting, not permissions', () {
      final recorder = Recorder()
        ..enqueue(
          apiError(403, 'quota exceeded', reason: 'quotaExceeded'),
          status: 403,
        );
      final guard = PlayApiGuard(retryPolicy: const RetryPolicy.none());

      expect(
        () => PlayEditSession.open(
          api: publisherApi(recorder),
          packageName: 'com.example.app',
          guard: guard,
        ),
        throwsA(isA<StoreRateLimitException>()),
      );
    });

    test('names the missing Play Console permission on a 403', () {
      final recorder = Recorder()
        ..enqueue(apiError(403, 'forbidden'), status: 403);
      final guard = PlayApiGuard(retryPolicy: const RetryPolicy.none());

      expect(
        () => PlayEditSession.open(
          api: publisherApi(recorder),
          packageName: 'com.example.app',
          guard: guard,
        ),
        throwsA(
          isA<StoreAuthException>().having(
            (error) => error.message,
            'message',
            contains('Users and permissions'),
          ),
        ),
      );
    });

    test('reads a 404 as an edit that is gone', () {
      final recorder = Recorder()
        ..enqueue(apiError(404, 'not found'), status: 404);
      final guard = PlayApiGuard(retryPolicy: const RetryPolicy.none());

      expect(
        () => PlayEditSession.open(
          api: publisherApi(recorder),
          packageName: 'com.example.app',
          guard: guard,
        ),
        throwsA(isA<PlayEditExpiredException>()),
      );
    });
  });
}
