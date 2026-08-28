import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Encodes [text] the way Google Play writes its report CSVs.
List<int> _utf16le(String text) {
  final bytes = <int>[0xFF, 0xFE];
  for (final unit in text.codeUnits) {
    bytes
      ..add(unit & 0xFF)
      ..add((unit >> 8) & 0xFF);
  }
  return bytes;
}

const _installsCsv =
    'Date,Package Name,Country,Daily Device Installs,Daily Device '
    'Uninstalls\n'
    '2026-08-20,com.example.app,JP,142,17\n'
    '2026-08-20,com.example.app,US,,3\n';

class _Recorder {
  final requests = <http.Request>[];
  final responses = <http.Response>[];

  MockClient get client => MockClient((request) async {
    requests.add(request);
    if (responses.isEmpty) return http.Response('{}', 200);
    return responses.removeAt(0);
  });

  void enqueueCsv(String csv) =>
      responses.add(http.Response.bytes(_utf16le(csv), 200));

  void enqueueJson(Object body, {int status = 200}) => responses.add(
    http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    ),
  );
}

PlayReportsApi _api(
  _Recorder recorder, {
  String bucket = 'pubsite_prod_rev_0123456789',
  RetryPolicy retryPolicy = const RetryPolicy.none(),
}) => PlayReportsApi(
  client: PlayStorageClient(
    authenticatedClient: recorder.client,
    retryPolicy: retryPolicy,
    sleep: (_) async {},
  ),
  bucket: bucket,
  packageName: 'com.example.app',
);

void main() {
  group('bucket id', () {
    test('accepts the URI Play Console copy button produces', () {
      // Pasting the whole URI is the obvious thing to do, and passing it
      // through raw fails with an error about an invalid bucket name.
      expect(
        PlayReportsApi.normaliseBucket(
          'gs://pubsite_prod_rev_0123456789/stats/installs/',
        ),
        'pubsite_prod_rev_0123456789',
      );
    });

    test('leaves a bare bucket id alone', () {
      expect(
        PlayReportsApi.normaliseBucket('  pubsite_prod_rev_0123456789 '),
        'pubsite_prod_rev_0123456789',
      );
    });
  });

  group('object names', () {
    test('builds the name Google publishes for a breakdown', () {
      expect(
        PlayReportType.installs.objectName(
          packageName: 'com.example.app',
          month: DateTime.utc(2026, 8, 20),
          dimension: 'country',
        ),
        'stats/installs/installs_com.example.app_202608_country.csv',
      );
    });

    test('pads a single-digit month', () {
      expect(
        PlayReportType.ratings.objectName(
          packageName: 'com.example.app',
          month: DateTime.utc(2026),
          dimension: 'overview',
        ),
        'stats/ratings/ratings_com.example.app_202601_overview.csv',
      );
    });

    test('reviews take no breakdown', () {
      expect(
        PlayReportType.reviews.objectName(
          packageName: 'com.example.app',
          month: DateTime.utc(2026, 8),
        ),
        'reviews/reviews_com.example.app_202608.csv',
      );
      expect(
        () => PlayReportType.reviews.objectName(
          packageName: 'com.example.app',
          month: DateTime.utc(2026, 8),
          dimension: 'country',
        ),
        throwsArgumentError,
      );
    });

    test('rejects a breakdown Google does not publish for the report', () {
      // Asking for one that does not exist is a 404 that reads like a month
      // with no data, so it is caught locally instead.
      expect(
        () => PlayReportType.crashes.objectName(
          packageName: 'com.example.app',
          month: DateTime.utc(2026, 8),
          dimension: 'carrier',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'lists the real ones',
            contains('os_version'),
          ),
        ),
      );
      // store_performance is the one report with no overview file.
      expect(
        () => PlayReportType.storePerformance.objectName(
          packageName: 'com.example.app',
          month: DateTime.utc(2026, 8),
          dimension: 'overview',
        ),
        throwsArgumentError,
      );
    });

    test('demands a breakdown for reports that have them', () {
      expect(
        () => PlayReportType.installs.objectName(
          packageName: 'com.example.app',
          month: DateTime.utc(2026, 8),
        ),
        throwsArgumentError,
      );
    });
  });

  group('fetch', () {
    test(
      'downloads the object with alt=media and a fully encoded name',
      () async {
        // The JSON API takes the object name as one path segment; leaving the
        // slashes raw resolves to a different, non-existent endpoint.
        final recorder = _Recorder()..enqueueCsv(_installsCsv);

        await _api(recorder).fetch(
          PlayReportType.installs,
          month: DateTime.utc(2026, 8),
          dimension: 'country',
        );

        final url = recorder.requests.single.url;
        expect(url.host, 'storage.googleapis.com');
        expect(
          url.toString(),
          contains(
            'stats%2Finstalls%2Finstalls_com.example.app_202608_country.csv',
          ),
        );
        expect(url.queryParameters['alt'], 'media');
        expect(
          url.path,
          startsWith('/storage/v1/b/pubsite_prod_rev_0123456789/o/'),
        );
      },
    );

    test('decodes the UTF-16LE CSV into a table', () async {
      final recorder = _Recorder()..enqueueCsv(_installsCsv);

      final table = await _api(recorder).fetch(
        PlayReportType.installs,
        month: DateTime.utc(2026, 8),
        dimension: 'country',
      );

      expect(table.length, 2);
      expect(table[0]['Country'], 'JP');
      expect(table[0].intAt('Daily Device Installs'), 142);
      expect(table[0].dateAt('Date'), DateTime.utc(2026, 8, 20));
      // An empty cell is null, not zero — Google leaves them blank.
      expect(table[1].intAt('Daily Device Installs'), isNull);
    });

    test('a month Google has not published is an empty table', () async {
      // Same reasoning as Apple's zero-sales 404: a missing month is an
      // answer, and a published report always carries a header row.
      final recorder = _Recorder()
        ..enqueueJson({
          'error': {'code': 404, 'message': 'No such object'},
        }, status: 404);

      final table = await _api(recorder).fetch(
        PlayReportType.installs,
        month: DateTime.utc(2026, 8),
        dimension: 'country',
      );

      expect(table.isEmpty, isTrue);
      expect(table.columns, isEmpty);
    });
  });

  group('list', () {
    test('lists by prefix rather than guessing month names', () async {
      // Google says not to depend on its publishing schedule, so which months
      // exist has to be discovered.
      final recorder = _Recorder()
        ..enqueueJson({
          'items': [
            {'name': 'stats/installs/installs_com.example.app_202608_c.csv'},
            {'name': 'stats/installs/installs_com.example.app_202607_c.csv'},
          ],
        });

      final names = await _api(recorder).list(PlayReportType.installs);

      expect(
        recorder.requests.single.url.queryParameters['prefix'],
        'stats/installs/installs_com.example.app',
      );
      // Sorted, so the oldest month comes first.
      expect(names.first, endsWith('202607_c.csv'));
    });

    test('follows nextPageToken', () async {
      final recorder = _Recorder()
        ..enqueueJson({
          'items': [
            {'name': 'a'},
          ],
          'nextPageToken': 'p2',
        })
        ..enqueueJson({
          'items': [
            {'name': 'b'},
          ],
        });

      final names = await _api(recorder).list(PlayReportType.installs);

      expect(names, ['a', 'b']);
      expect(recorder.requests[1].url.queryParameters['pageToken'], 'p2');
    });

    test('is empty when the bucket has nothing for the app', () async {
      final recorder = _Recorder()..enqueueJson(<String, dynamic>{});

      expect(await _api(recorder).list(PlayReportType.reviews), isEmpty);
    });
  });

  group('fetchAll', () {
    test('downloads every published month of one breakdown', () async {
      final recorder = _Recorder()
        ..enqueueJson({
          'items': [
            {
              'name':
                  'stats/installs/installs_com.example.app_202607_country.csv',
            },
            {
              'name':
                  'stats/installs/installs_com.example.app_202607_device.csv',
            },
            {
              'name':
                  'stats/installs/installs_com.example.app_202608_country.csv',
            },
          ],
        })
        ..enqueueCsv(_installsCsv)
        ..enqueueCsv(_installsCsv);

      final tables = await _api(
        recorder,
      ).fetchAll(PlayReportType.installs, dimension: 'country').toList();

      // The device breakdown is skipped, so two downloads follow the listing.
      expect(tables, hasLength(2));
      expect(recorder.requests, hasLength(3));
    });

    test('stops downloading when the caller stops consuming', () async {
      final recorder = _Recorder()
        ..enqueueJson({
          'items': [
            {'name': 'reviews/reviews_com.example.app_202607.csv'},
            {'name': 'reviews/reviews_com.example.app_202608.csv'},
          ],
        })
        ..enqueueCsv('Review Text\nGood\n')
        ..enqueueCsv('Review Text\nAlso good\n');

      await _api(recorder).fetchAll(PlayReportType.reviews).first;

      expect(recorder.requests, hasLength(2));
    });
  });

  group('errors', () {
    test('names the scope and the bucket when access is denied', () async {
      // A service account with a valid key that was never invited in Play
      // Console fails exactly here, and Google's message does not say so.
      final recorder = _Recorder()
        ..enqueueJson({
          'error': {
            'code': 403,
            'message': 'does not have storage.objects.list access',
          },
        }, status: 403);

      await expectLater(
        _api(recorder).list(PlayReportType.installs),
        throwsA(
          isA<StoreAuthException>()
              .having((e) => e.store, 'store', Store.googlePlay)
              .having(
                (e) => e.message,
                'message',
                contains('storageReadScope'),
              ),
        ),
      );
    });

    test('a 404 on listing still throws, unlike one on download', () async {
      // A missing bucket is a configuration error; a missing object is a
      // month with no data.
      final recorder = _Recorder()
        ..enqueueJson({
          'error': {
            'code': 404,
            'message':
                'The specified bucket does not '
                'exist',
          },
        }, status: 404);

      await expectLater(
        _api(recorder).list(PlayReportType.installs),
        throwsA(
          isA<StoreApiException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    });

    test('retries a 503 and succeeds', () async {
      final recorder = _Recorder()
        ..enqueueJson({
          'error': {'code': 503, 'message': 'Backend Error'},
        }, status: 503)
        ..enqueueCsv(_installsCsv);

      final table = await _api(recorder, retryPolicy: const RetryPolicy())
          .fetch(
            PlayReportType.installs,
            month: DateTime.utc(2026, 8),
            dimension: 'country',
          );

      expect(recorder.requests, hasLength(2));
      expect(table.length, 2);
    });
  });
}
