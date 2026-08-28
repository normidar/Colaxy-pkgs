import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'test_api_key.dart';

/// Records every request and answers from a scripted queue.
class _Recorder {
  final requests = <http.Request>[];
  final responses = <http.Response>[];

  MockClient get client => MockClient((request) async {
    requests.add(request);
    if (responses.isEmpty) return http.Response('{}', 200);
    return responses.removeAt(0);
  });

  void enqueue(Object body, {int status = 200}) => responses.add(
    http.Response(
      body is String ? body : jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    ),
  );
}

/// Builds an API over [recorder].
///
/// Retries are off by default so a test that scripts one response gets
/// exactly one request; the retry tests opt back in with their own policy and
/// a fake clock, so no test ever actually sleeps.
AppStoreReviewsApi _api(
  _Recorder recorder, {
  RetryPolicy retryPolicy = const RetryPolicy.none(),
  List<Duration>? waits,
}) => AppStoreReviewsApi(
  client: AppStoreConnectClient(
    apiKey: testApiKey(),
    httpClient: recorder.client,
    retryPolicy: retryPolicy,
    sleep: (duration) async => waits?.add(duration),
  ),
  appId: '6740000000',
);

Map<String, dynamic> _reviewPage({String? next, int total = 1}) => {
  'data': [
    {
      'type': 'customerReviews',
      'id': 'review-1',
      'attributes': {
        'rating': 3,
        'title': 'Fine',
        'body': 'It works.',
        'reviewerNickname': 'sam',
        'createdDate': '2026-08-20T00:00:00Z',
        'territory': 'USA',
      },
      'relationships': <String, dynamic>{},
    },
  ],
  'links': {'next': ?next},
  'meta': {
    'paging': {'total': total},
  },
};

void main() {
  group('listPage', () {
    test('requests the documented endpoint with the bearer token', () async {
      final recorder = _Recorder()..enqueue(_reviewPage());

      await _api(recorder).listPage();

      final request = recorder.requests.single;
      expect(request.method, 'GET');
      expect(request.url.host, 'api.appstoreconnect.apple.com');
      expect(request.url.path, '/v1/apps/6740000000/customerReviews');
      expect(request.headers['Authorization'], startsWith('Bearer ey'));
    });

    test('translates the query into Apple filter parameters', () async {
      final recorder = _Recorder()..enqueue(_reviewPage());

      await _api(recorder).listPage(
        const ReviewQuery(
          pageSize: 50,
          ratings: {2, 1},
          territories: {'JPN'},
          hasReply: false,
          sort: ReviewSort.lowestRating,
        ),
      );

      final query = recorder.requests.single.url.queryParameters;
      expect(query['limit'], '50');
      expect(query['include'], 'response');
      // Sorted so the URL is stable and cache-friendly across runs.
      expect(query['filter[rating]'], '1,2');
      expect(query['filter[territory]'], 'JPN');
      expect(query['exists[publishedResponse]'], 'false');
      expect(query['sort'], 'rating');
    });

    test('clamps a page size above Apple maximum', () async {
      final recorder = _Recorder()..enqueue(_reviewPage());

      await _api(recorder).listPage(const ReviewQuery(pageSize: 5000));

      expect(recorder.requests.single.url.queryParameters['limit'], '200');
    });

    test('omits filters that were not set', () async {
      final recorder = _Recorder()..enqueue(_reviewPage());

      await _api(recorder).listPage();

      final query = recorder.requests.single.url.queryParameters;
      expect(query.keys, ['include']);
    });

    test('exposes the next link and total', () async {
      final recorder = _Recorder()
        ..enqueue(_reviewPage(next: 'https://api.example/next', total: 412));

      final page = await _api(recorder).listPage();

      expect(page.store, Store.appStore);
      expect(page.reviews, hasLength(1));
      expect(page.nextCursor, 'https://api.example/next');
      expect(page.total, 412);
      expect(page.isLast, isFalse);
    });

    test('follows a cursor verbatim instead of rebuilding it', () async {
      // Apple's `links.next` already carries every filter; rebuilding the URL
      // from the query would risk dropping one and silently re-listing.
      final recorder = _Recorder()..enqueue(_reviewPage());
      const cursor =
          'https://api.appstoreconnect.apple.com/v1/apps/1/customerReviews'
          '?cursor=BQ.ab&limit=7';

      await _api(recorder).listPage(const ReviewQuery(cursor: cursor));

      expect(recorder.requests.single.url.toString(), cursor);
    });
  });

  group('list', () {
    test('pages until the store stops sending a next link', () async {
      final recorder = _Recorder()
        ..enqueue(_reviewPage(next: 'https://api.example/p2'))
        ..enqueue(_reviewPage(next: 'https://api.example/p3'))
        ..enqueue(_reviewPage());

      final reviews = await _api(recorder).list().toList();

      expect(reviews, hasLength(3));
      expect(recorder.requests, hasLength(3));
    });

    test('stops fetching when the caller stops consuming', () async {
      // Every extra page is quota spent for nothing.
      final recorder = _Recorder()
        ..enqueue(_reviewPage(next: 'https://api.example/p2'))
        ..enqueue(_reviewPage(next: 'https://api.example/p3'));

      await _api(recorder).list().first;

      expect(recorder.requests, hasLength(1));
    });
  });

  group('reply', () {
    test('POSTs a new response when the review has none', () async {
      final recorder = _Recorder()
        // GET /response → 404, i.e. not answered yet.
        ..enqueue({
          'errors': [
            {'status': '404', 'code': 'NOT_FOUND', 'title': 'Not found'},
          ],
        }, status: 404)
        ..enqueue({
          'data': {
            'type': 'customerReviewResponses',
            'id': 'resp-9',
            'attributes': {
              'responseBody': 'Thanks!',
              'state': 'PENDING_PUBLISH',
              'lastModifiedDate': '2026-08-21T00:00:00Z',
            },
          },
        });

      final reply = await _api(recorder).reply('review-1', 'Thanks!');

      final post = recorder.requests.last;
      expect(post.method, 'POST');
      expect(post.url.path, '/v1/customerReviewResponses');
      final body = jsonDecode(post.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      expect(data['type'], 'customerReviewResponses');
      expect((data['attributes'] as Map)['responseBody'], 'Thanks!');
      final review =
          ((data['relationships'] as Map)['review'] as Map)['data'] as Map;
      expect(review['id'], 'review-1');
      expect(review['type'], 'customerReviews');

      expect(reply.id, 'resp-9');
      expect(reply.state, ReviewReplyState.pendingPublish);
    });

    test('PATCHes the existing response instead of POSTing again', () async {
      // A second POST for the same review comes back 409.
      final recorder = _Recorder()
        ..enqueue({
          'data': {'type': 'customerReviewResponses', 'id': 'resp-9'},
        })
        ..enqueue({
          'data': {
            'type': 'customerReviewResponses',
            'id': 'resp-9',
            'attributes': {'responseBody': 'Updated.', 'state': 'PUBLISHED'},
          },
        });

      final reply = await _api(recorder).reply('review-1', 'Updated.');

      final patch = recorder.requests.last;
      expect(patch.method, 'PATCH');
      expect(patch.url.path, '/v1/customerReviewResponses/resp-9');
      expect(
        ((jsonDecode(patch.body) as Map)['data'] as Map)['id'],
        'resp-9',
      );
      expect(reply.body, 'Updated.');
      expect(reply.state, ReviewReplyState.published);
    });

    test('does not enforce a length Apple never published', () async {
      // The widely-quoted 5,970 is community-measured; Apple's own spec
      // leaves responseBody unconstrained. Blocking on it would reject
      // replies the store would have taken, so the request goes out and
      // Apple's answer is the authority.
      final recorder = _Recorder()
        ..enqueue({
          'errors': [
            {'status': '404', 'code': 'NOT_FOUND', 'title': 'Not found'},
          ],
        }, status: 404)
        ..enqueue({
          'data': {
            'type': 'customerReviewResponses',
            'id': 'resp-9',
            'attributes': {'responseBody': 'x', 'state': 'PUBLISHED'},
          },
        });

      await _api(recorder).reply('review-1', 'x' * 8000);

      expect(recorder.requests, hasLength(2));
      expect(
        AppStoreReviewsApi.advisoryReplyLength,
        5970,
        reason: 'still exposed for callers who want to warn',
      );
    });

    test('rejects a blank body', () async {
      final recorder = _Recorder();

      expect(
        () => _api(recorder).reply('review-1', '   '),
        throwsArgumentError,
      );
      expect(recorder.requests, isEmpty);
    });
  });

  group('get', () {
    test('returns null for a review Apple does not have', () async {
      final recorder = _Recorder()
        ..enqueue({
          'errors': [
            {'status': '404', 'code': 'NOT_FOUND', 'title': 'Not found'},
          ],
        }, status: 404);

      expect(await _api(recorder).get('missing'), isNull);
    });
  });

  group('error mapping', () {
    test('surfaces the error title, code and detail', () async {
      final recorder = _Recorder()
        ..enqueue({
          'errors': [
            {
              'status': '403',
              'code': 'FORBIDDEN_ERROR',
              'title': 'This request is forbidden for security reasons',
              'detail': 'The API key in use does not allow this request',
            },
          ],
        }, status: 403);

      await expectLater(
        _api(recorder).listPage(),
        throwsA(
          isA<StoreApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.code, 'code', 'FORBIDDEN_ERROR')
              .having((e) => e.store, 'store', Store.appStore)
              .having((e) => e.detail, 'detail', contains('API key')),
        ),
      );
    });

    test('maps 429 to a rate limit error carrying retry-after', () async {
      final recorder = _Recorder();
      recorder.responses.add(
        http.Response(
          jsonEncode({
            'errors': [
              {'status': '429', 'code': 'RATE_LIMIT_EXCEEDED', 'title': 'Slow'},
            ],
          }),
          429,
          headers: const {'retry-after': '120'},
        ),
      );

      await expectLater(
        _api(recorder).listPage(),
        throwsA(
          isA<StoreRateLimitException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 120),
          ),
        ),
      );
    });

    test('retries once with a fresh token on 401', () async {
      // A token can be accepted then rejected inside its own lifetime.
      final recorder = _Recorder()
        ..enqueue({
          'errors': [
            {'status': '401', 'title': 'Expired'},
          ],
        }, status: 401)
        ..enqueue(_reviewPage());

      final page = await _api(recorder).listPage();

      expect(recorder.requests, hasLength(2));
      expect(page.reviews, hasLength(1));
    });

    test('gives up after a second 401', () async {
      final recorder = _Recorder()
        ..enqueue({
          'errors': [
            {'status': '401', 'title': 'Bad key'},
          ],
        }, status: 401)
        ..enqueue({
          'errors': [
            {'status': '401', 'title': 'Bad key'},
          ],
        }, status: 401);

      await expectLater(
        _api(recorder).listPage(),
        throwsA(isA<StoreAuthException>()),
      );
      expect(recorder.requests, hasLength(2));
    });

    test('retries a 429 and succeeds, waiting what Apple asked for', () async {
      final waits = <Duration>[];
      final recorder = _Recorder();
      recorder.responses.add(
        http.Response(
          jsonEncode({
            'errors': [
              {'status': '429', 'code': 'RATE_LIMIT_EXCEEDED', 'title': 'Slow'},
            ],
          }),
          429,
          headers: const {'retry-after': '7'},
        ),
      );
      recorder.enqueue(_reviewPage());

      final page = await _api(
        recorder,
        retryPolicy: const RetryPolicy(),
        waits: waits,
      ).listPage();

      expect(recorder.requests, hasLength(2));
      expect(page.reviews, hasLength(1));
      expect(waits, [const Duration(seconds: 7)]);
    });

    test('backs off exponentially across repeated 500s', () async {
      final waits = <Duration>[];
      final recorder = _Recorder()
        ..enqueue({'errors': <dynamic>[]}, status: 500)
        ..enqueue({'errors': <dynamic>[]}, status: 500)
        ..enqueue(_reviewPage());

      await _api(
        recorder,
        retryPolicy: const RetryPolicy(),
        waits: waits,
      ).listPage();

      expect(recorder.requests, hasLength(3));
      expect(waits, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    });

    test('gives up once maxAttempts is spent', () async {
      final waits = <Duration>[];
      final recorder = _Recorder()
        ..enqueue({'errors': <dynamic>[]}, status: 503)
        ..enqueue({'errors': <dynamic>[]}, status: 503)
        ..enqueue({'errors': <dynamic>[]}, status: 503)
        ..enqueue(_reviewPage());

      await expectLater(
        _api(
          recorder,
          retryPolicy: const RetryPolicy(),
          waits: waits,
        ).listPage(),
        throwsA(isA<StoreApiException>()),
      );
      expect(recorder.requests, hasLength(3));
    });

    test('does not retry a 403, which would fail the same way', () async {
      final recorder = _Recorder()
        ..enqueue({
          'errors': [
            {'status': '403', 'code': 'FORBIDDEN_ERROR', 'title': 'No'},
          ],
        }, status: 403)
        ..enqueue(_reviewPage());

      await expectLater(
        _api(recorder, retryPolicy: const RetryPolicy()).listPage(),
        throwsA(isA<StoreApiException>()),
      );
      expect(recorder.requests, hasLength(1));
    });

    test('reports retries and re-signs through onLog', () async {
      final logs = <String>[];
      final recorder = _Recorder()
        ..enqueue({
          'errors': [
            {'status': '401', 'title': 'Expired'},
          ],
        }, status: 401)
        ..enqueue({'errors': <dynamic>[]}, status: 500)
        ..enqueue(_reviewPage());

      await AppStoreReviewsApi(
        client: AppStoreConnectClient(
          apiKey: testApiKey(),
          httpClient: recorder.client,
          onLog: logs.add,
          sleep: (_) async {},
        ),
        appId: '6740000000',
      ).listPage();

      expect(logs, hasLength(2));
      expect(logs.first, contains('re-signing'));
      expect(logs.last, contains('retrying in'));
    });

    test('still throws a typed error for a body that is not JSON', () async {
      // Gateway failures come back as HTML, not the documented envelope.
      final recorder = _Recorder()
        ..enqueue('<html><body>502 Bad Gateway</body></html>', status: 502);

      await expectLater(
        _api(recorder).listPage(),
        throwsA(
          isA<StoreApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having((e) => e.detail, 'detail', contains('Bad Gateway')),
        ),
      );
    });
  });
}
