import 'dart:convert';
import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'test_api_key.dart';

/// The header and two rows of a `SALES`/`SUMMARY` report, with the column
/// names Apple actually sends.
const _report =
    'Provider\tProvider Country\tSKU\tDeveloper\tTitle\tVersion\t'
    'Product Type Identifier\tUnits\tDeveloper Proceeds\tBegin Date\t'
    'End Date\tCustomer Currency\tCountry Code\n'
    'APPLE\tUS\tcom.example.app\tExample Inc\tExample\t2.4.1\t1F\t12\t0.70\t'
    '08/20/2026\t08/20/2026\tJPY\tJP\n'
    'APPLE\tUS\tcom.example.pro\tExample Inc\tExample Pro\t2.4.1\t1F\t3\t'
    '2.10\t08/20/2026\t08/20/2026\tUSD\tUS\n';

class _Recorder {
  final requests = <http.Request>[];
  final responses = <http.Response>[];

  MockClient get client => MockClient((request) async {
    requests.add(request);
    if (responses.isEmpty) return http.Response('{}', 200);
    return responses.removeAt(0);
  });

  void enqueueReport(String tsv) => responses.add(
    http.Response.bytes(
      gzip.encode(utf8.encode(tsv)),
      200,
      headers: const {'content-type': 'application/a-gzip'},
    ),
  );

  void enqueueError(Object body, {int status = 400}) => responses.add(
    http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    ),
  );
}

SalesReportsApi _api(_Recorder recorder) => SalesReportsApi(
  client: AppStoreConnectClient(
    apiKey: testApiKey(),
    httpClient: recorder.client,
    retryPolicy: const RetryPolicy.none(),
  ),
  vendorNumber: '85000000',
);

void main() {
  group('fetch', () {
    test('requests the documented endpoint with the report filters', () async {
      final recorder = _Recorder()..enqueueReport(_report);

      await _api(recorder).fetch(
        SalesReportQuery.sales(date: DateTime.utc(2026, 8, 20)),
      );

      final request = recorder.requests.single;
      expect(request.url.path, '/v1/salesReports');
      expect(request.url.queryParameters, {
        'filter[frequency]': 'DAILY',
        'filter[reportType]': 'SALES',
        'filter[reportSubType]': 'SUMMARY',
        'filter[vendorNumber]': '85000000',
        'filter[version]': '1_0',
        'filter[reportDate]': '2026-08-20',
      });
      expect(request.headers['Accept'], 'application/a-gzip');
      expect(request.headers['Authorization'], startsWith('Bearer ey'));
    });

    test('decompresses the gzipped TSV into a table', () async {
      // Apple serves gzip with no Content-Encoding, so nothing in the HTTP
      // stack unzips it first.
      final recorder = _Recorder()..enqueueReport(_report);

      final table = await _api(recorder).fetch(SalesReportQuery.sales());

      expect(table.length, 2);
      expect(table.columns.first, 'Provider');
      expect(table[0]['SKU'], 'com.example.app');
      expect(table[0].intAt('Units'), 12);
      expect(table[0].decimalAt('Developer Proceeds'), 0.70);
      expect(table[0].dateAt('Begin Date'), DateTime.utc(2026, 8, 20));
    });

    test(
      'sums units across the whole account, which is what a report is',
      () async {
        // Sales reports cover every app under the vendor number; there is no
        // per-app filter in the API.
        final recorder = _Recorder()..enqueueReport(_report);

        final table = await _api(recorder).fetch(SalesReportQuery.sales());
        final units = table.entries.fold<int>(
          0,
          (sum, row) => sum + (row.intAt('Units') ?? 0),
        );

        expect(units, 15);
        expect(
          table.entries.map((row) => row['SKU']).toSet(),
          {'com.example.app', 'com.example.pro'},
        );
      },
    );
  });

  group('no data', () {
    test('a zero-sales day is an empty table, not a failure', () async {
      // Apple answers a quiet day with 404 "There were no sales for the date
      // specified". Treating that as an error would break every such day.
      final recorder = _Recorder()
        ..enqueueError({
          'errors': [
            {
              'status': '404',
              'code': 'NOT_FOUND',
              'title': 'The request expected results but none were found',
              'detail': 'There were no sales for the date specified.',
            },
          ],
        }, status: 404);

      final table = await _api(recorder).fetch(SalesReportQuery.sales());

      expect(table.isEmpty, isTrue);
      // A report that exists always has a header, so no columns means no
      // report — which distinguishes this from a report with zero rows.
      expect(table.columns, isEmpty);
    });

    test('a generated report with no rows keeps its header', () async {
      final recorder = _Recorder()..enqueueReport('Provider\tUnits\n');

      final table = await _api(recorder).fetch(SalesReportQuery.sales());

      expect(table.isEmpty, isTrue);
      expect(table.columns, isNotEmpty);
    });
  });

  group('errors', () {
    test('a 400 still throws, unlike a 404', () async {
      final recorder = _Recorder()
        ..enqueueError({
          'errors': [
            {
              'status': '400',
              'code': 'PARAMETER_ERROR.INVALID.INVALID_COMBINATION',
              'title': 'A parameter has an invalid value',
              'detail': 'Invalid combination of date type and date',
            },
          ],
        });

      await expectLater(
        _api(recorder).fetch(SalesReportQuery.sales()),
        throwsA(
          isA<StoreApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.store, 'store', Store.appStore),
        ),
      );
    });

    test('an impossible query fails before any request', () async {
      final recorder = _Recorder();

      expect(
        () => SalesReportQuery(
          type: SalesReportType.subscriber,
          subType: SalesReportSubType.detailed,
          frequency: SalesFrequency.yearly,
          date: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
      expect(recorder.requests, isEmpty);
    });
  });

  group('fetchAll', () {
    test('fetches sequentially and keeps empty periods in place', () async {
      // Lining up one-to-one with the queries matters: a caller zipping
      // results against dates would silently shift every row otherwise.
      final recorder = _Recorder()
        ..enqueueReport(_report)
        ..enqueueError({
          'errors': [
            {'status': '404', 'code': 'NOT_FOUND', 'title': 'None'},
          ],
        }, status: 404)
        ..enqueueReport(_report);

      final tables = await _api(recorder).fetchAll([
        SalesReportQuery.sales(date: DateTime.utc(2026, 8, 20)),
        SalesReportQuery.sales(date: DateTime.utc(2026, 8, 21)),
        SalesReportQuery.sales(date: DateTime.utc(2026, 8, 22)),
      ]).toList();

      expect(tables.map((t) => t.length), [2, 0, 2]);
      expect(recorder.requests, hasLength(3));
      expect(
        recorder.requests.map(
          (r) => r.url.queryParameters['filter[reportDate]'],
        ),
        ['2026-08-20', '2026-08-21', '2026-08-22'],
      );
    });

    test('stops fetching when the caller stops consuming', () async {
      final recorder = _Recorder()
        ..enqueueReport(_report)
        ..enqueueReport(_report);

      await _api(recorder).fetchAll([
        SalesReportQuery.sales(date: DateTime.utc(2026, 8, 20)),
        SalesReportQuery.sales(date: DateTime.utc(2026, 8, 21)),
      ]).first;

      expect(recorder.requests, hasLength(1));
    });
  });

  group('AppStoreTeam', () {
    test('wires the vendor number through to the reports API', () async {
      final recorder = _Recorder()..enqueueReport(_report);
      final team = AppStoreTeam.withClient(
        client: AppStoreConnectClient(
          apiKey: testApiKey(),
          httpClient: recorder.client,
          retryPolicy: const RetryPolicy.none(),
        ),
        vendorNumber: '85123456',
      );

      await team.salesReports.fetch(SalesReportQuery.sales());

      expect(
        recorder.requests.single.url.queryParameters['filter[vendorNumber]'],
        '85123456',
      );
      expect(team.vendorNumber, '85123456');
    });
  });
}
