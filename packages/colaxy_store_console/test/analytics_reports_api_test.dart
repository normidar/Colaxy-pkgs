import 'dart:convert';
import 'dart:io';

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
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    ),
  );

  void enqueueGzip(String tsv) => responses.add(
    http.Response.bytes(gzip.encode(utf8.encode(tsv)), 200),
  );
}

AnalyticsReportsApi _api(_Recorder recorder) => AnalyticsReportsApi(
  client: AppStoreConnectClient(
    apiKey: testApiKey(),
    httpClient: recorder.client,
    retryPolicy: const RetryPolicy.none(),
  ),
  appId: '6740000000',
);

Map<String, dynamic> _request({
  String id = 'req-1',
  String accessType = 'ONGOING',
  bool stopped = false,
}) => {
  'type': 'analyticsReportRequests',
  'id': id,
  'attributes': {
    'accessType': accessType,
    'stoppedDueToInactivity': stopped,
  },
};

void main() {
  group('createRequest', () {
    test('posts the resource Apple documents', () async {
      final recorder = _Recorder()..enqueue({'data': _request()});

      final request = await _api(
        recorder,
      ).createRequest(AnalyticsAccessType.ongoing);

      final post = recorder.requests.single;
      expect(post.method, 'POST');
      expect(post.url.path, '/v1/analyticsReportRequests');

      final data =
          (jsonDecode(post.body) as Map<String, dynamic>)['data']!
              as Map<String, dynamic>;
      expect(data['type'], 'analyticsReportRequests');
      expect((data['attributes']! as Map)['accessType'], 'ONGOING');
      final app =
          ((data['relationships']! as Map)['app']! as Map)['data']! as Map;
      expect(app, {'type': 'apps', 'id': '6740000000'});

      expect(request.id, 'req-1');
      expect(request.accessType, AnalyticsAccessType.ongoing);
      expect(request.isLive, isTrue);
    });
  });

  group('requests', () {
    test('lists the app requests, optionally filtered', () async {
      final recorder = _Recorder()
        ..enqueue({
          'data': [_request(), _request(id: 'req-2', stopped: true)],
        });

      final requests = await _api(
        recorder,
      ).requests(accessType: AnalyticsAccessType.ongoing);

      expect(
        recorder.requests.single.url.path,
        '/v1/apps/6740000000/analyticsReportRequests',
      );
      expect(
        recorder.requests.single.url.queryParameters['filter[accessType]'],
        'ONGOING',
      );
      expect(requests.map((r) => r.id), ['req-1', 'req-2']);
      expect(requests[1].stoppedDueToInactivity, isTrue);
      expect(requests[1].isLive, isFalse);
    });
  });

  group('ensureRequest', () {
    test('reuses a live request rather than creating another', () async {
      final recorder = _Recorder()
        ..enqueue({
          'data': [_request()],
        });

      final request = await _api(
        recorder,
      ).ensureRequest(AnalyticsAccessType.ongoing);

      expect(request.id, 'req-1');
      expect(recorder.requests, hasLength(1), reason: 'no POST');
    });

    test('creates one when every existing request has been stopped', () async {
      // Apple stops requests that go unread and deletes their data; a stopped
      // request produces nothing and its IDs no longer resolve.
      final recorder = _Recorder()
        ..enqueue({
          'data': [_request(stopped: true)],
        })
        ..enqueue({'data': _request(id: 'req-new')});

      final request = await _api(
        recorder,
      ).ensureRequest(AnalyticsAccessType.ongoing);

      expect(request.id, 'req-new');
      expect(recorder.requests.last.method, 'POST');
    });

    test('creates one when there are none at all', () async {
      final recorder = _Recorder()
        ..enqueue({'data': <dynamic>[]})
        ..enqueue({'data': _request(id: 'req-new')});

      expect(
        (await _api(recorder).ensureRequest(AnalyticsAccessType.ongoing)).id,
        'req-new',
      );
    });
  });

  group('the chain', () {
    test('reports filters by category', () async {
      final recorder = _Recorder()
        ..enqueue({
          'data': [
            {
              'type': 'analyticsReports',
              'id': 'rep-1',
              'attributes': {
                'name': 'App Store Discovery and Engagement Standard',
                'category': 'APP_STORE_ENGAGEMENT',
              },
            },
          ],
        });

      final reports = await _api(recorder).reports(
        'req-1',
        category: AnalyticsReportCategory.appStoreEngagement,
      );

      expect(
        recorder.requests.single.url.path,
        '/v1/analyticsReportRequests/req-1/reports',
      );
      expect(
        recorder.requests.single.url.queryParameters['filter[category]'],
        'APP_STORE_ENGAGEMENT',
      );
      expect(
        reports.single.category,
        AnalyticsReportCategory.appStoreEngagement,
      );
      expect(reports.single.name, contains('Discovery'));
    });

    test('instances filter by granularity and processing date', () async {
      final recorder = _Recorder()
        ..enqueue({
          'data': [
            {
              'type': 'analyticsReportInstances',
              'id': 'inst-1',
              'attributes': {
                'granularity': 'DAILY',
                'processingDate': '2026-08-20',
              },
            },
          ],
        });

      final instances = await _api(recorder).instances(
        'rep-1',
        granularity: AnalyticsGranularity.daily,
        processingDate: DateTime.utc(2026, 8, 20),
      );

      final query = recorder.requests.single.url.queryParameters;
      expect(query['filter[granularity]'], 'DAILY');
      expect(query['filter[processingDate]'], '2026-08-20');
      expect(instances.single.granularity, AnalyticsGranularity.daily);
      expect(instances.single.processingDate, DateTime.utc(2026, 8, 20));
    });

    test('segments carry the pre-signed URL and size', () async {
      final recorder = _Recorder()
        ..enqueue({
          'data': [
            {
              'type': 'analyticsReportSegments',
              'id': 'seg-1',
              'attributes': {
                'url': 'https://reports.example/seg-1?sig=abc',
                'checksum': 'deadbeef',
                'sizeInBytes': 4096,
              },
            },
          ],
        });

      final segments = await _api(recorder).segments('inst-1');

      expect(
        recorder.requests.single.url.path,
        '/v1/analyticsReportInstances/inst-1/segments',
      );
      expect(segments.single.url, 'https://reports.example/seg-1?sig=abc');
      expect(segments.single.sizeInBytes, 4096);
      expect(segments.single.checksum, 'deadbeef');
    });
  });

  group('download', () {
    test(
      'fetches a segment from its own host without the bearer token',
      () async {
        // The URL is pre-signed and lives off the API host; Apple's token has
        // no bearing on it.
        final recorder = _Recorder()..enqueueGzip('Date\tImpressions\n');

        await _api(recorder).downloadSegment(
          const AnalyticsReportSegment(
            id: 'seg-1',
            url: 'https://reports.example/seg-1?sig=abc',
          ),
        );

        expect(recorder.requests.single.url.host, 'reports.example');
      },
    );

    test('joins an instance segments into one table', () async {
      // Each segment is an independent file with its own header row; only
      // the concatenation is the report.
      final recorder = _Recorder()
        ..enqueue({
          'data': [
            {
              'type': 'analyticsReportSegments',
              'id': 'seg-1',
              'attributes': {'url': 'https://reports.example/1'},
            },
            {
              'type': 'analyticsReportSegments',
              'id': 'seg-2',
              'attributes': {'url': 'https://reports.example/2'},
            },
          ],
        })
        ..enqueueGzip('Date\tImpressions\n2026-08-20\t100\n')
        ..enqueueGzip('Date\tImpressions\n2026-08-21\t250\n');

      final table = await _api(recorder).downloadInstance('inst-1');

      expect(table.length, 2);
      expect(table.columns, ['Date', 'Impressions']);
      expect(table[1].intAt('Impressions'), 250);
    });

    test('an instance with no segments is an empty table', () async {
      final recorder = _Recorder()..enqueue({'data': <dynamic>[]});

      expect((await _api(recorder).downloadInstance('inst-1')).isEmpty, isTrue);
    });

    test('an expired segment URL surfaces as a typed failure', () async {
      // Pre-signed URLs expire; the remedy is to list the segments again.
      final recorder = _Recorder()
        ..enqueue({
          'errors': [
            {'status': '403', 'code': 'FORBIDDEN', 'title': 'Expired'},
          ],
        }, status: 403);

      await expectLater(
        _api(recorder).downloadSegment(
          const AnalyticsReportSegment(id: 'seg-1', url: 'https://x.example/1'),
        ),
        throwsA(isA<StoreApiException>()),
      );
    });
  });

  group('deleteRequest', () {
    test('deletes the resource', () async {
      final recorder = _Recorder()..responses.add(http.Response('', 204));

      await _api(recorder).deleteRequest('req-1');

      expect(recorder.requests.single.method, 'DELETE');
      expect(
        recorder.requests.single.url.path,
        '/v1/analyticsReportRequests/req-1',
      );
    });
  });

  group('unknown enum values', () {
    test('are tolerated rather than thrown on', () {
      // Apple adds categories and granularities without notice; one must not
      // fail a whole listing.
      expect(AnalyticsReportCategory.parse('SOME_FUTURE_CATEGORY'), isNull);
      expect(AnalyticsGranularity.parse('QUARTERLY'), isNull);
      expect(AnalyticsAccessType.parse(null), isNull);

      final report = AnalyticsReport.fromJson(const {
        'id': 'rep-1',
        'attributes': {'name': 'Whatever', 'category': 'NEW_THING'},
      });
      expect(report.category, isNull);
      expect(report.name, 'Whatever');
    });

    test('a resource with no attributes still parses', () {
      final instance = AnalyticsReportInstance.fromJson(const {'id': 'i'});

      expect(instance.id, 'i');
      expect(instance.granularity, isNull);
      expect(instance.processingDate, isNull);
    });
  });

  group('ReportTable.concat', () {
    test('appends rows under one shared header', () {
      final joined = ReportTable.concat([
        ReportTable.fromTsv('a\tb\n1\t2\n'),
        ReportTable.fromTsv('a\tb\n3\t4\n'),
      ]);

      expect(joined.columns, ['a', 'b']);
      expect(joined.length, 2);
    });

    test('skips empty tables so a quiet period does not blank the result', () {
      final joined = ReportTable.concat([
        ReportTable.empty(),
        ReportTable.fromTsv('a\tb\n1\t2\n'),
      ]);

      expect(joined.length, 1);
      expect(joined.columns, ['a', 'b']);
    });

    test('ignores header case and spacing differences', () {
      expect(
        () => ReportTable.concat([
          ReportTable.fromTsv('Date\tUnits\n1\t2\n'),
          ReportTable.fromTsv('date\tunits\n3\t4\n'),
        ]),
        returnsNormally,
      );
    });

    test('refuses to join tables whose columns disagree', () {
      // Appending rows under the wrong header shifts every value one column
      // over and produces plausible-looking nonsense.
      expect(
        () => ReportTable.concat([
          ReportTable.fromTsv('a\tb\n1\t2\n'),
          ReportTable.fromTsv('a\tc\n3\t4\n'),
        ]),
        throwsStateError,
      );
    });

    test('joining nothing yields an empty table', () {
      expect(ReportTable.concat(const []).isEmpty, isTrue);
    });
  });
}
