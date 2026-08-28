import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:googleapis/androidpublisher/v3.dart' as play;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'test_api_key.dart';

class _Recorder {
  final requests = <http.Request>[];
  final responses = <http.Response>[];
  bool closed = false;

  http.Client get client => _CloseSpy(
    MockClient((request) async {
      requests.add(request);
      if (responses.isEmpty) return http.Response('{}', 200);
      return responses.removeAt(0);
    }),
    () => closed = true,
  );

  void enqueue(Object body) => responses.add(
    http.Response(
      jsonEncode(body),
      200,
      headers: const {'content-type': 'application/json'},
    ),
  );
}

/// Wraps a client so a test can see whether `close()` reached it.
class _CloseSpy extends http.BaseClient {
  _CloseSpy(this._inner, this._onClose);

  final http.Client _inner;
  final void Function() _onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    _onClose();
    _inner.close();
  }
}

GooglePlayConsole _play(_Recorder recorder) {
  final client = recorder.client;
  return GooglePlayConsole(
    packageName: 'com.example.app',
    reviews: PlayReviewsApi(
      api: play.AndroidPublisherApi(client),
      packageName: 'com.example.app',
      httpClient: client,
      retryPolicy: const RetryPolicy.none(),
    ),
  );
}

AppStoreConnectConsole _appStore(_Recorder recorder) =>
    AppStoreConnectConsole.withClient(
      client: AppStoreConnectClient(
        apiKey: testApiKey(),
        httpClient: recorder.client,
        retryPolicy: const RetryPolicy.none(),
      ),
      appId: '6740000000',
    );

void main() {
  group('construction', () {
    test('needs at least one store', () {
      expect(StoreConsole.new, throwsA(isA<AssertionError>()));
    });

    test('works with only one store configured', () {
      final console = StoreConsole(appStore: _appStore(_Recorder()));

      expect(console.googlePlay, isNull);
      // With one store the merged view can answer the questions that are
      // ambiguous across two.
      expect(console.reviews.store, Store.appStore);
    });

    test('reviews spans both stores when both are configured', () {
      final console = StoreConsole(
        googlePlay: _play(_Recorder()),
        appStore: _appStore(_Recorder()),
      );

      expect(() => console.reviews.store, throwsStateError);
      expect(console.reviews.listPage, throwsUnsupportedError);
    });
  });

  group('connect', () {
    test('rejects a half-supplied pair rather than reading nothing', () async {
      // A typo in one argument would otherwise produce a console that
      // silently covers no stores at all.
      await expectLater(
        StoreConsole.connect(appStoreKey: testApiKey()),
        throwsArgumentError,
      );
      await expectLater(
        StoreConsole.connect(appId: '6740000000'),
        throwsArgumentError,
      );
      await expectLater(StoreConsole.connect(), throwsArgumentError);
    });

    test('builds the App Store side alone', () async {
      final console = await StoreConsole.connect(
        appStoreKey: testApiKey(),
        appId: '6740000000',
      );

      expect(console.appStore, isNotNull);
      expect(console.googlePlay, isNull);
      console.close();
    });
  });

  group('close', () {
    test('reaches every configured store', () async {
      // Left open, the process will not exit.
      final playRecorder = _Recorder();
      StoreConsole(googlePlay: _play(playRecorder)).close();

      expect(playRecorder.closed, isTrue);
    });

    test('leaves a client the caller owns alone', () {
      // `_appStore` supplies the transport, so closing it is the caller's
      // call to make — they may still be using it for another app.
      final appStoreRecorder = _Recorder();

      StoreConsole(appStore: _appStore(appStoreRecorder)).close();

      expect(appStoreRecorder.closed, isFalse);
    });

    test('the Play clients honour ownsClient', () {
      // One `authenticate(scopes: [...])` call can cover several Play APIs,
      // and the first close() must not shut the client the others need.
      final shared = _Recorder();
      final client = shared.client;

      PlayVitalsApi(
        client: PlayReportingClient(
          authenticatedClient: client,
          ownsClient: false,
        ),
        packageName: 'com.example.app',
      ).close();
      expect(shared.closed, isFalse);

      PlayReportsApi(
        client: PlayStorageClient(authenticatedClient: client),
        bucket: 'pubsite_prod_rev_0',
        packageName: 'com.example.app',
      ).close();
      expect(shared.closed, isTrue);
    });
  });

  group('AppStoreConnectConsole', () {
    test('exposes reviews and analytics over one shared client', () {
      // Sharing the transport shares the cached bearer token, which is the
      // point of holding a console rather than building each API.
      final console = _appStore(_Recorder());

      expect(console.reviews.appId, '6740000000');
      expect(console.analytics.appId, '6740000000');
      expect(console.client, isA<AppStoreConnectClient>());
    });
  });

  group('merged review paging', () {
    test('drops a cursor rather than handing it to the wrong store', () async {
      // Apple's cursor is a URL and Google's an opaque token. Forwarding one
      // to both delegates would send at least one store a cursor it cannot
      // read, and Play would answer with an unrelated page.
      final playRecorder = _Recorder()..enqueue({'reviews': <dynamic>[]});
      final appStoreRecorder = _Recorder()..enqueue({'data': <dynamic>[]});
      final console = StoreConsole(
        googlePlay: _play(playRecorder),
        appStore: _appStore(appStoreRecorder),
      );
      await console.reviews
          .list(
            const ReviewQuery(
              cursor: 'https://api.example/page2',
              ratings: {1},
            ),
          )
          .toList();

      expect(
        playRecorder.requests.single.url.queryParameters.containsKey('token'),
        isFalse,
      );
      // The App Store side starts from the collection, not from the cursor.
      expect(
        appStoreRecorder.requests.single.url.path,
        '/v1/apps/6740000000/customerReviews',
      );
      // The rest of the query still gets through.
      expect(
        appStoreRecorder.requests.single.url.queryParameters['filter[rating]'],
        '1',
      );
    });
  });
}
