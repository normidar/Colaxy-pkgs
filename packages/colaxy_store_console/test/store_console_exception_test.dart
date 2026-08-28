import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:test/test.dart';

void main() {
  group('toString', () {
    test('names the concrete failure, not the base class', () {
      // These read out of logs and CI output. `runtimeType` cannot be used —
      // minified builds do not preserve type names — so each subclass carries
      // its own label, and a missed override would silently mislabel it.
      expect(
        const StoreAuthException('bad key', store: Store.appStore).toString(),
        '[App Store] StoreAuthException: bad key',
      );
      expect(
        const ReviewNotFoundException(
          'gone',
          store: Store.googlePlay,
        ).toString(),
        '[Google Play] ReviewNotFoundException: gone',
      );
      expect(
        const StoreConsoleException('generic').toString(),
        'StoreConsoleException: generic',
      );
    });

    test('every subclass overrides the label', () {
      // A subclass that forgets to override inherits the wrong name.
      final labels = <String>{
        const StoreConsoleException('x').label,
        const StoreAuthException('x').label,
        const StoreApiException('x', statusCode: 1).label,
        const StoreRateLimitException('x', statusCode: 1).label,
        const ReviewNotFoundException('x').label,
      };

      expect(labels, hasLength(5));
    });

    test('omits the store prefix when the store is unknown', () {
      // Credential failures happen before a store is picked.
      expect(
        const StoreAuthException('no key').toString(),
        startsWith('StoreAuthException:'),
      );
    });

    test('an API failure carries status, code and detail', () {
      const error = StoreApiException(
        'This request is forbidden',
        statusCode: 403,
        store: Store.appStore,
        code: 'FORBIDDEN_ERROR',
        detail: 'The API key in use does not allow this request',
      );

      expect(
        error.toString(),
        '[App Store] StoreApiException: HTTP 403 (FORBIDDEN_ERROR) — '
        'This request is forbidden\n'
        'The API key in use does not allow this request',
      );
    });

    test('a rate limit failure reports as its own type', () {
      const error = StoreRateLimitException(
        'Quota exceeded',
        statusCode: 429,
        store: Store.googlePlay,
        retryAfter: Duration(seconds: 30),
      );

      expect(error.toString(), contains('StoreRateLimitException'));
      expect(error.retryAfter, const Duration(seconds: 30));
    });
  });

  group('hierarchy', () {
    test('everything is catchable as StoreConsoleException', () {
      // So a caller can wrap a whole pipeline in one handler.
      const failures = <StoreConsoleException>[
        StoreAuthException('x'),
        StoreApiException('x', statusCode: 1),
        StoreRateLimitException('x', statusCode: 1),
        ReviewNotFoundException('x'),
      ];

      expect(failures, everyElement(isA<Exception>()));
    });

    test('a rate limit is a kind of API failure, and auth is not', () {
      // `on StoreApiException` should catch throttling; it must not swallow a
      // credentials problem, which no amount of retrying fixes.
      expect(
        const StoreRateLimitException('x', statusCode: 429),
        isA<StoreApiException>(),
      );
      expect(const StoreAuthException('x'), isNot(isA<StoreApiException>()));
    });
  });
}
