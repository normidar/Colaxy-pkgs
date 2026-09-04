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

    test('names the missing Play Console permission on a 401', () {
      // 401 is what Play answers for a service account that was never
      // invited, so the diagnosis can be stated outright.
      final recorder = Recorder()
        ..enqueue(apiError(401, 'unauthorized'), status: 401);
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

    test('does not call a rejected request a permission problem', () {
      // Real data: `edits.validate` answers
      //   403 "This app has more than 8 screenshots for language ja-JP."
      // with an empty `errors` array — indistinguishable by status from a
      // permission failure. Reporting it as StoreAuthException told the
      // caller to check permissions that were fine.
      final recorder = Recorder()
        ..enqueue(
          apiError(403, 'This app has more than 8 screenshots for ja-JP.'),
          status: 403,
        );
      final guard = PlayApiGuard(retryPolicy: const RetryPolicy.none());

      expect(
        () => PlayEditSession.open(
          api: publisherApi(recorder),
          packageName: 'com.example.app',
          guard: guard,
        ),
        throwsA(
          allOf(
            isA<StoreApiException>().having(
              (error) => error.message,
              'message',
              contains('more than 8 screenshots'),
            ),
            isNot(isA<StoreAuthException>()),
          ),
        ),
      );
    });

    test('a 403 still carries the permission hint, in detail', () {
      // The hint is real for the other kind of 403, so it stays reachable —
      // just not as the headline.
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
          isA<StoreApiException>().having(
            (error) => error.detail,
            'detail',
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
