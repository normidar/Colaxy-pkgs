import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:test/test.dart';

void main() {
  group('shouldRetry', () {
    const policy = RetryPolicy();

    test('retries throttling and the transient server errors', () {
      for (final status in [429, 500, 502, 503, 504]) {
        expect(
          policy.shouldRetry(attempt: 1, statusCode: status),
          isTrue,
          reason: '$status should be retried',
        );
      }
    });

    test('never retries a request that is simply wrong', () {
      // The same request would fail the same way, so a retry only wastes
      // quota and delays the error the caller needs to see.
      for (final status in [400, 401, 403, 404, 409, 422]) {
        expect(
          policy.shouldRetry(attempt: 1, statusCode: status),
          isFalse,
          reason: '$status should not be retried',
        );
      }
    });

    test('stops once maxAttempts is reached', () {
      expect(policy.shouldRetry(attempt: 2, statusCode: 429), isTrue);
      expect(policy.shouldRetry(attempt: 3, statusCode: 429), isFalse);
    });

    test('RetryPolicy.none() never retries anything', () {
      const none = RetryPolicy.none();

      expect(none.shouldRetry(attempt: 1, statusCode: 429), isFalse);
      expect(none.shouldRetry(attempt: 1, statusCode: 503), isFalse);
    });
  });

  group('backoffFor', () {
    test('grows by the multiplier on each attempt', () {
      // Default initialBackoff is 1 second; the ceiling is raised so it does
      // not truncate the curve being asserted.
      const policy = RetryPolicy(maxBackoff: Duration(minutes: 1));

      expect(policy.backoffFor(1), const Duration(seconds: 1));
      expect(policy.backoffFor(2), const Duration(seconds: 2));
      expect(policy.backoffFor(3), const Duration(seconds: 4));
      expect(policy.backoffFor(4), const Duration(seconds: 8));
    });

    test('caps at maxBackoff', () {
      const policy = RetryPolicy(maxBackoff: Duration(seconds: 5));

      expect(policy.backoffFor(10), const Duration(seconds: 5));
    });

    test('prefers the store Retry-After over the curve', () {
      // The store knows its own quota window; a backoff curve is a guess.
      const policy = RetryPolicy(maxBackoff: Duration(minutes: 10));

      expect(
        policy.backoffFor(1, retryAfter: const Duration(seconds: 90)),
        const Duration(seconds: 90),
      );
    });

    test('still caps a Retry-After that would stall the job', () {
      // A misreported header must not park a CI run for an hour. The default
      // 30-second ceiling applies to Retry-After just as it does to the curve.
      const policy = RetryPolicy();

      expect(
        policy.backoffFor(1, retryAfter: const Duration(hours: 1)),
        const Duration(seconds: 30),
      );
    });
  });

  group('construction', () {
    test('rejects a non-positive attempt count', () {
      expect(() => RetryPolicy(maxAttempts: 0), throwsA(isA<AssertionError>()));
    });

    test('rejects a shrinking multiplier', () {
      expect(
        () => RetryPolicy(multiplier: 0.5),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
