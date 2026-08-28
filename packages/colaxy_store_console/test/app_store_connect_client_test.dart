import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'test_api_key.dart';

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

AppStoreConnectClient _client(_Recorder recorder) => AppStoreConnectClient(
  apiKey: testApiKey(),
  httpClient: recorder.client,
  retryPolicy: const RetryPolicy.none(),
);

Map<String, dynamic> _page(List<String> ids, {String? next}) => {
  'data': [
    for (final id in ids) {'type': 'apps', 'id': id},
  ],
  'links': {'next': ?next},
};

void main() {
  group('query encoding', () {
    test('joins list values with commas and drops nulls and empties', () async {
      final recorder = _Recorder()..enqueue(_page([]));

      await _client(recorder).getJson(
        '/v1/apps',
        query: {
          'filter[id]': ['a', 'b'],
          'limit': 10,
          'sort': null,
          'filter[empty]': <String>[],
        },
      );

      // A caller building filters conditionally should not have to prune the
      // map first.
      final query = recorder.requests.single.url.queryParameters;
      expect(query, {'filter[id]': 'a,b', 'limit': '10'});
    });
  });

  group('pages', () {
    test('follows links.next until it stops', () async {
      final recorder = _Recorder()
        ..enqueue(_page(['1'], next: 'https://api.example/p2'))
        ..enqueue(_page(['2'], next: 'https://api.example/p3'))
        ..enqueue(_page(['3']));

      final pages = await _client(recorder).pages('/v1/apps').toList();

      expect(pages, hasLength(3));
      expect(pages.last.isLast, isTrue);
      expect(recorder.requests[1].url.toString(), 'https://api.example/p2');
    });

    test('fetches lazily, so stopping early stops the requests', () async {
      final recorder = _Recorder()
        ..enqueue(_page(['1'], next: 'https://api.example/p2'))
        ..enqueue(_page(['2'], next: 'https://api.example/p3'));

      await _client(recorder).pages('/v1/apps').first;

      expect(recorder.requests, hasLength(1));
    });
  });

  group('resources', () {
    test('flattens every page into one stream', () async {
      final recorder = _Recorder()
        ..enqueue(_page(['1', '2'], next: 'https://api.example/p2'))
        ..enqueue(_page(['3']));

      final ids = await _client(
        recorder,
      ).resources('/v1/apps').map((r) => r['id']).toList();

      expect(ids, ['1', '2', '3']);
    });
  });

  group('delete', () {
    test('accepts the empty 204 body Apple sends', () async {
      final recorder = _Recorder()..responses.add(http.Response('', 204));

      await _client(recorder).delete('/v1/customerReviewResponses/r1');

      expect(recorder.requests.single.method, 'DELETE');
    });
  });

  group('close', () {
    test('leaves a caller-supplied client alone', () {
      // Its owner may still be using it; closing it would break them.
      final recorder = _Recorder();
      final shared = recorder.client;

      AppStoreConnectClient(apiKey: testApiKey(), httpClient: shared).close();

      // Still usable: a closed MockClient would throw here.
      expect(
        () => shared.get(Uri.parse('https://api.example/')),
        returnsNormally,
      );
    });
  });
}
