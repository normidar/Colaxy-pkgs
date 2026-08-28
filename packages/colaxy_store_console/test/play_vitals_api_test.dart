import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

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
}

PlayVitalsApi _api(
  _Recorder recorder, {
  RetryPolicy retryPolicy = const RetryPolicy.none(),
}) => PlayVitalsApi(
  client: PlayReportingClient(
    authenticatedClient: recorder.client,
    retryPolicy: retryPolicy,
    sleep: (_) async {},
  ),
  packageName: 'com.example.app',
);

/// A row as the API returns it: several metrics under one bucket.
Map<String, dynamic> _row({
  required int day,
  Map<String, String> metrics = const {'crashRate': '0.0231'},
  Map<String, String> dimensions = const {},
}) => {
  'startTime': {'year': 2026, 'month': 8, 'day': day},
  'aggregationPeriod': 'DAILY',
  if (dimensions.isNotEmpty)
    'dimensions': [
      for (final entry in dimensions.entries)
        {'dimension': entry.key, 'stringValue': entry.value},
    ],
  'metrics': [
    for (final entry in metrics.entries)
      {
        'metric': entry.key,
        'decimalValue': {'value': entry.value},
      },
  ],
};

VitalsQuery _query({
  List<String> metrics = const ['crashRate'],
  List<String> dimensions = const [],
}) => VitalsQuery(
  metricSet: VitalsMetricSet.crashRate,
  metrics: metrics,
  from: DateTime.utc(2026, 8, 20),
  to: DateTime.utc(2026, 8, 22),
  dimensions: dimensions,
);

void main() {
  group('query', () {
    test('posts to the metric set resource under the version prefix', () async {
      final recorder = _Recorder()..enqueue({'rows': <dynamic>[]});

      await _api(recorder).query(_query());

      final request = recorder.requests.single;
      expect(request.method, 'POST');
      expect(request.url.host, 'playdeveloperreporting.googleapis.com');
      expect(
        request.url.path,
        '/v1beta1/apps/com.example.app/crashRateMetricSet:query',
      );
      expect(jsonDecode(request.body), _query().toRequestBody());
    });

    test('pivots rows carrying several metrics into one series each', () async {
      // Google returns one row per bucket with all requested metrics on it;
      // a StoreMetric is one metric over time, so the response is transposed.
      final recorder = _Recorder()
        ..enqueue({
          'rows': [
            _row(
              day: 20,
              metrics: {'crashRate': '0.02', 'distinctUsers': '1200'},
            ),
            _row(
              day: 21,
              metrics: {'crashRate': '0.04', 'distinctUsers': '1300'},
            ),
          ],
        });

      final metrics = await _api(
        recorder,
      ).query(_query(metrics: const ['crashRate', 'distinctUsers']));

      expect(metrics.keys, unorderedEquals(['crashRate', 'distinctUsers']));
      expect(metrics['crashRate']!.points, hasLength(2));
      expect(metrics['crashRate']!.average, closeTo(0.03, 1e-9));
      expect(metrics['distinctUsers']!.total, 2500);
    });

    test('tags each series with the right unit', () {
      // distinctUsers is a count even inside a rate metric set; averaging it
      // as a rate would be nonsense.
      expect(
        VitalsMetricSet.crashRate.unitFor('distinctUsers'),
        MetricUnit.count,
      );
    });

    test('parses decimals from the string Google sends', () async {
      // google.type.Decimal is always a string; reading it as a number would
      // yield null and silently drop the point.
      final recorder = _Recorder()
        ..enqueue({
          'rows': [
            _row(day: 20, metrics: {'crashRate': '0.00012345'}),
          ],
        });

      final metrics = await _api(recorder).query(_query());

      expect(metrics['crashRate']!.points.single.value, 0.00012345);
    });

    test(
      'keeps dimension values, including int64 ones sent as strings',
      () async {
        final recorder = _Recorder()
          ..enqueue({
            'rows': [
              {
                'startTime': {'year': 2026, 'month': 8, 'day': 20},
                'dimensions': [
                  {'dimension': 'countryCode', 'stringValue': 'JP'},
                  {'dimension': 'versionCode', 'int64Value': '1234'},
                ],
                'metrics': [
                  {
                    'metric': 'crashRate',
                    'decimalValue': {'value': '0.02'},
                  },
                ],
              },
            ],
          });

        final metrics = await _api(
          recorder,
        ).query(_query(dimensions: const ['countryCode', 'versionCode']));

        expect(metrics['crashRate']!.points.single.dimensions, {
          'countryCode': 'JP',
          'versionCode': '1234',
        });
      },
    );

    test('labels a daily bucket with the date Google reported', () async {
      // A DAILY bucket is an America/Los_Angeles day. Shifting it into real
      // UTC would move it off midnight and, at the edges, onto another date —
      // so the civil date is kept as-is to match Play Console.
      final recorder = _Recorder()
        ..enqueue({
          'rows': [_row(day: 20)],
        });

      final metrics = await _api(recorder).query(_query());

      expect(
        metrics['crashRate']!.points.single.date,
        DateTime.utc(2026, 8, 20),
      );
    });

    test('follows nextPageToken until it stops', () async {
      final recorder = _Recorder()
        ..enqueue({
          'rows': [_row(day: 20)],
          'nextPageToken': 'p2',
        })
        ..enqueue({
          'rows': [_row(day: 21)],
          'nextPageToken': 'p3',
        })
        ..enqueue({
          'rows': [_row(day: 22)],
        });

      final metrics = await _api(recorder).query(_query());

      expect(recorder.requests, hasLength(3));
      expect(metrics['crashRate']!.points, hasLength(3));
      expect(
        jsonDecode(recorder.requests[1].body),
        containsPair('pageToken', 'p2'),
      );
    });

    test('omits a metric Google returned no data for', () async {
      // Absent and zero are different answers; an empty series would read as
      // "we measured nothing happened".
      final recorder = _Recorder()
        ..enqueue({
          'rows': [
            _row(day: 20, metrics: {'crashRate': '0.02'}),
          ],
        });

      final metrics = await _api(
        recorder,
      ).query(_query(metrics: const ['crashRate', 'distinctUsers']));

      expect(metrics.containsKey('distinctUsers'), isFalse);
    });

    test('returns nothing for an empty response', () async {
      final recorder = _Recorder()..enqueue(<String, dynamic>{});

      expect(await _api(recorder).query(_query()), isEmpty);
    });
  });

  group('queryOne', () {
    test('returns the named series', () async {
      final recorder = _Recorder()
        ..enqueue({
          'rows': [_row(day: 20)],
        });

      final metric = await _api(recorder).queryOne(_query(), 'crashRate');

      expect(metric.points, hasLength(1));
      expect(metric.unit, MetricUnit.rate);
    });

    test('returns a well-formed empty series when there is no data', () async {
      // So a caller can chart it without branching.
      final recorder = _Recorder()..enqueue({'rows': <dynamic>[]});

      final metric = await _api(recorder).queryOne(_query(), 'crashRate');

      expect(metric.isEmpty, isTrue);
      expect(metric.store, Store.googlePlay);
      expect(metric.name, 'crashRate');
      expect(metric.unit, MetricUnit.rate);
    });
  });

  group('freshness', () {
    test('reads the latest settled bucket per period', () async {
      final recorder = _Recorder()
        ..enqueue({
          'name': 'apps/com.example.app/crashRateMetricSet',
          'freshnessInfo': {
            'freshnesses': [
              {
                'aggregationPeriod': 'DAILY',
                'latestEndTime': {'year': 2026, 'month': 8, 'day': 20},
              },
              {
                'aggregationPeriod': 'HOURLY',
                'latestEndTime': {
                  'year': 2026,
                  'month': 8,
                  'day': 21,
                  'hours': 6,
                },
              },
            ],
          },
        });

      final freshness = await _api(
        recorder,
      ).freshness(VitalsMetricSet.crashRate);

      expect(recorder.requests.single.method, 'GET');
      expect(
        recorder.requests.single.url.path,
        '/v1beta1/apps/com.example.app/crashRateMetricSet',
      );
      expect(
        freshness.latestEndTimeFor(AggregationPeriod.daily),
        DateTime.utc(2026, 8, 20),
      );
      expect(
        freshness.latestEndTimeFor(AggregationPeriod.hourly),
        DateTime.utc(2026, 8, 21, 6),
      );
    });

    test('clamp trims a query end past the settled data', () async {
      // Storing still-moving buckets as final is how a pipeline ends up
      // disagreeing with Play Console.
      final freshness = MetricFreshness({
        AggregationPeriod.daily: _august20,
      });

      expect(
        freshness.clamp(DateTime.utc(2026, 8, 25), AggregationPeriod.daily),
        _august20,
      );
      expect(
        freshness.clamp(DateTime.utc(2026, 8, 10), AggregationPeriod.daily),
        DateTime.utc(2026, 8, 10),
      );
    });

    test('clamp leaves the end alone when freshness is unreported', () async {
      // Refusing to fetch on missing metadata would be worse than fetching
      // data that might still move.
      const unknown = MetricFreshness.unknown();

      expect(
        unknown.clamp(DateTime.utc(2026, 8, 25), AggregationPeriod.daily),
        DateTime.utc(2026, 8, 25),
      );
      expect(unknown.isEmpty, isTrue);
    });

    test('ignores an aggregation period this package does not model', () async {
      // Google adds enum members without notice; one must not fail the read.
      final recorder = _Recorder()
        ..enqueue({
          'freshnessInfo': {
            'freshnesses': [
              {
                'aggregationPeriod': 'SOME_FUTURE_PERIOD',
                'latestEndTime': {'year': 2026, 'month': 8, 'day': 20},
              },
              {
                'aggregationPeriod': 'DAILY',
                'latestEndTime': {'year': 2026, 'month': 8, 'day': 20},
              },
            ],
          },
        });

      final freshness = await _api(
        recorder,
      ).freshness(VitalsMetricSet.crashRate);

      expect(freshness.latestEndTimes, hasLength(1));
    });
  });

  group('errors', () {
    test('names the scope when Google denies permission', () async {
      // A token minted for the Android Publisher scope is rejected here, and
      // the rejection otherwise looks like a bad key.
      final recorder = _Recorder()
        ..enqueue({
          'error': {
            'code': 403,
            'message': 'The caller does not have permission',
            'status': 'PERMISSION_DENIED',
          },
        }, status: 403);

      await expectLater(
        _api(recorder).query(_query()),
        throwsA(
          isA<StoreAuthException>()
              .having((e) => e.store, 'store', Store.googlePlay)
              .having((e) => e.message, 'message', contains('reportingScope')),
        ),
      );
    });

    test('maps RESOURCE_EXHAUSTED to a rate limit error', () async {
      final recorder = _Recorder()
        ..enqueue({
          'error': {
            'code': 429,
            'message': 'Quota exceeded',
            'status': 'RESOURCE_EXHAUSTED',
          },
        }, status: 429);

      await expectLater(
        _api(recorder).query(_query()),
        throwsA(isA<StoreRateLimitException>()),
      );
    });

    test('retries a RESOURCE_EXHAUSTED sent as 403', () async {
      // Google signals an exhausted quota with either status; the translated
      // type is the reliable signal for whether to retry.
      final recorder = _Recorder()
        ..enqueue({
          'error': {
            'code': 403,
            'message': 'Quota exceeded',
            'status': 'RESOURCE_EXHAUSTED',
          },
        }, status: 403)
        ..enqueue({
          'rows': [_row(day: 20)],
        });

      final metrics = await _api(
        recorder,
        retryPolicy: const RetryPolicy(),
      ).query(_query());

      expect(recorder.requests, hasLength(2));
      expect(metrics['crashRate']!.points, hasLength(1));
    });

    test('keeps other failures as StoreApiException', () async {
      final recorder = _Recorder()
        ..enqueue({
          'error': {
            'code': 400,
            'message': 'Invalid dimension',
            'status': 'INVALID_ARGUMENT',
          },
        }, status: 400);

      await expectLater(
        _api(recorder).query(_query()),
        throwsA(
          isA<StoreApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'INVALID_ARGUMENT'),
        ),
      );
    });

    test('still throws a typed error for a body that is not JSON', () async {
      final recorder = _Recorder()
        ..responses.add(http.Response('<html>502</html>', 502));

      await expectLater(
        _api(recorder).query(_query()),
        throwsA(
          isA<StoreApiException>().having((e) => e.statusCode, 'status', 502),
        ),
      );
    });
  });
}

final _august20 = DateTime.utc(2026, 8, 20);
