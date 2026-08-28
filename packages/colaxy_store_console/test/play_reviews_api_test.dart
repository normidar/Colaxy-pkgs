import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Records requests and answers from a scripted queue.
class _Recorder {
  final requests = <http.BaseRequest>[];
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

PlayReviewsApi _api(_Recorder recorder) => PlayReviewsApi(
  api: play.AndroidPublisherApi(recorder.client),
  packageName: 'com.example.app',
);

Map<String, dynamic> _review({
  required String id,
  required int rating,
  String? replyText,
}) => {
  'reviewId': id,
  'authorName': 'Kenji',
  'comments': [
    {
      'userComment': {
        'text': 'Review $id',
        'starRating': rating,
        'lastModified': {'seconds': '1787212800', 'nanos': 0},
      },
    },
    if (replyText != null)
      {
        'developerComment': {
          'text': replyText,
          'lastModified': {'seconds': '1787299200', 'nanos': 0},
        },
      },
  ],
};

Map<String, dynamic> _page(
  List<Map<String, dynamic>> reviews, {
  String? nextToken,
}) => {
  'reviews': reviews,
  if (nextToken != null) 'tokenPagination': {'nextPageToken': nextToken},
};

void main() {
  group('listPage', () {
    test('calls the reviews endpoint for the package', () async {
      final recorder = _Recorder()..enqueue(_page([]));

      await _api(recorder).listPage();

      final url = recorder.requests.single.url;
      expect(
        url.path,
        '/androidpublisher/v3/applications/com.example.app/reviews',
      );
    });

    test('passes page size, cursor and translation language', () async {
      final recorder = _Recorder()..enqueue(_page([]));

      await _api(recorder).listPage(
        const ReviewQuery(
          pageSize: 40,
          cursor: 'token-2',
          translationLanguage: 'ja',
        ),
      );

      final query = recorder.requests.single.url.queryParameters;
      expect(query['maxResults'], '40');
      expect(query['token'], 'token-2');
      expect(query['translationLanguage'], 'ja');
    });

    test('clamps a page size above the Play maximum', () async {
      final recorder = _Recorder()..enqueue(_page([]));

      await _api(recorder).listPage(const ReviewQuery(pageSize: 900));

      expect(
        recorder.requests.single.url.queryParameters['maxResults'],
        '100',
      );
    });

    test('exposes the next page token as the cursor', () async {
      final recorder = _Recorder()
        ..enqueue(_page([_review(id: 'a', rating: 5)], nextToken: 'tok'));

      final page = await _api(recorder).listPage();

      expect(page.store, Store.googlePlay);
      expect(page.nextCursor, 'tok');
      expect(page.isLast, isFalse);
      // Google never reports a total for reviews.
      expect(page.total, isNull);
    });

    test('filters by rating client-side, since Play has no filter', () async {
      final recorder = _Recorder()
        ..enqueue(
          _page([
            _review(id: 'a', rating: 5),
            _review(id: 'b', rating: 1),
            _review(id: 'c', rating: 2),
          ]),
        );

      final page = await _api(recorder).listPage(
        const ReviewQuery(ratings: {1, 2}),
      );

      expect(page.reviews.map((r) => r.id), ['b', 'c']);
      // The filter must not leak into the request; Play would reject it.
      expect(
        recorder.requests.single.url.queryParameters.keys,
        isNot(contains('filter[rating]')),
      );
    });

    test('filters by hasReply client-side', () async {
      final recorder = _Recorder()
        ..enqueue(
          _page([
            _review(id: 'a', rating: 1, replyText: 'Sorry!'),
            _review(id: 'b', rating: 1),
          ]),
        );

      final api = _api(recorder);
      final unanswered = await api.listPage(
        const ReviewQuery(hasReply: false),
      );

      expect(unanswered.reviews.map((r) => r.id), ['b']);
    });

    test('can return an empty page while more still remain', () async {
      // Client-side filtering can empty a page. Paging therefore has to be
      // driven off the cursor, which is why ReviewPage exposes isLast.
      final recorder = _Recorder()
        ..enqueue(_page([_review(id: 'a', rating: 5)], nextToken: 'tok'));

      final page = await _api(recorder).listPage(
        const ReviewQuery(ratings: {1}),
      );

      expect(page.reviews, isEmpty);
      expect(page.isLast, isFalse);
    });
  });

  group('list', () {
    test('pages until Play stops sending a token', () async {
      final recorder = _Recorder()
        ..enqueue(_page([_review(id: 'a', rating: 4)], nextToken: 't2'))
        ..enqueue(_page([_review(id: 'b', rating: 4)], nextToken: 't3'))
        ..enqueue(_page([_review(id: 'c', rating: 4)]));

      final reviews = await _api(recorder).list().toList();

      expect(reviews.map((r) => r.id), ['a', 'b', 'c']);
      expect(recorder.requests, hasLength(3));
    });

    test('keeps paging past a page emptied by the filter', () async {
      final recorder = _Recorder()
        ..enqueue(_page([_review(id: 'a', rating: 5)], nextToken: 't2'))
        ..enqueue(_page([_review(id: 'b', rating: 1)]));

      final reviews = await _api(
        recorder,
      ).list(const ReviewQuery(ratings: {1})).toList();

      expect(reviews.map((r) => r.id), ['b']);
    });
  });

  group('reply', () {
    test('posts the reply text and maps the result', () async {
      final recorder = _Recorder()
        ..enqueue({
          'result': {
            'replyText': 'Thanks for the report.',
            'lastEdited': {'seconds': '1787299200', 'nanos': 0},
          },
        });

      final api = _api(recorder);
      final reply = await api.reply('gp:1', 'Thanks for the report.');

      final request = recorder.requests.single as http.Request;
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/reviews/gp%3A1:reply'));
      expect(
        jsonDecode(request.body),
        {'replyText': 'Thanks for the report.'},
      );
      expect(reply.store, Store.googlePlay);
      expect(reply.body, 'Thanks for the report.');
      expect(reply.state, ReviewReplyState.published);
    });

    test('rejects a body over the 350-character Play limit', () async {
      // Play counts characters, not bytes, and rejects the whole request —
      // which would cost one of the 2,000 daily writes for nothing.
      final recorder = _Recorder();

      expect(
        () => _api(recorder).reply('gp:1', 'x' * 351),
        throwsArgumentError,
      );
      expect(recorder.requests, isEmpty);
    });

    test('accepts a body at exactly the limit', () async {
      final recorder = _Recorder()
        ..enqueue({
          'result': {'replyText': 'x'},
        });

      await _api(recorder).reply('gp:1', 'x' * 350);

      expect(recorder.requests, hasLength(1));
    });

    test('rejects a blank body', () async {
      final recorder = _Recorder();

      expect(() => _api(recorder).reply('gp:1', ' \n '), throwsArgumentError);
      expect(recorder.requests, isEmpty);
    });
  });

  group('error mapping', () {
    test('turns a 403 quota error into StoreRateLimitException', () async {
      // Play signals exhausted quota with 403, not the 429 used elsewhere.
      final recorder = _Recorder()
        ..enqueue({
          'error': {
            'code': 403,
            'message': 'Quota exceeded for quota metric reviews',
            'errors': [
              {'reason': 'quotaExceeded', 'message': 'Quota exceeded'},
            ],
          },
        }, status: 403);

      await expectLater(
        _api(recorder).listPage(),
        throwsA(
          isA<StoreRateLimitException>()
              .having((e) => e.store, 'store', Store.googlePlay)
              .having((e) => e.code, 'code', 'quotaExceeded')
              .having((e) => e.detail, 'detail', contains('200 review reads')),
        ),
      );
    });

    test('explains a 401 in terms of the Play Console invitation', () async {
      // A valid JSON key that was never invited in Play Console is the most
      // common setup failure, and Google's own message does not say so.
      final recorder = _Recorder()
        ..enqueue({
          'error': {
            'code': 401,
            'message':
                'The current user has insufficient '
                'permissions',
          },
        }, status: 401);

      await expectLater(
        _api(recorder).listPage(),
        throwsA(
          isA<StoreAuthException>().having(
            (e) => e.message,
            'message',
            contains('Users and permissions'),
          ),
        ),
      );
    });

    test(
      'get() returns null for a review outside the seven-day window',
      () async {
        final recorder = _Recorder()
          ..enqueue({
            'error': {'code': 404, 'message': 'Review not found'},
          }, status: 404);

        expect(await _api(recorder).get('gp:old'), isNull);
      },
    );

    test('keeps other statuses as StoreApiException', () async {
      final recorder = _Recorder()
        ..enqueue({
          'error': {'code': 500, 'message': 'Backend error'},
        }, status: 500);

      await expectLater(
        _api(recorder).listPage(),
        throwsA(
          isA<StoreApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.store, 'store', Store.googlePlay),
        ),
      );
    });
  });
}
