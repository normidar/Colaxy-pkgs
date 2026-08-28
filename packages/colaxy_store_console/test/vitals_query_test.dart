import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:test/test.dart';

VitalsQuery _query({
  VitalsMetricSet metricSet = VitalsMetricSet.crashRate,
  List<String> metrics = const ['crashRate'],
  AggregationPeriod period = AggregationPeriod.daily,
  List<String> dimensions = const [],
}) => VitalsQuery(
  metricSet: metricSet,
  metrics: metrics,
  from: DateTime.utc(2026, 8, 2),
  to: DateTime.utc(2026, 8, 21),
  period: period,
  dimensions: dimensions,
);

void main() {
  group('request body', () {
    test('builds the timeline spec Google documents', () {
      expect(_query().toRequestBody(), {
        'timelineSpec': {
          'aggregationPeriod': 'DAILY',
          'startTime': {'year': 2026, 'month': 8, 'day': 2},
          'endTime': {'year': 2026, 'month': 8, 'day': 21},
        },
        'metrics': ['crashRate'],
      });
    });

    test('sends hours only at hourly granularity', () {
      // A daily boundary carrying an hour is rejected, and the message does
      // not say which field is at fault.
      final hourly = VitalsQuery(
        metricSet: VitalsMetricSet.crashRate,
        metrics: const ['crashRate'],
        from: DateTime.utc(2026, 8, 1, 6),
        to: DateTime.utc(2026, 8, 2, 6),
        period: AggregationPeriod.hourly,
      );

      final spec = hourly.toRequestBody()['timelineSpec']! as Map;
      expect(spec['startTime'], {
        'year': 2026,
        'month': 8,
        'day': 1,
        'hours': 6,
      });
      expect(
        (_query().toRequestBody()['timelineSpec']! as Map)['startTime'],
        isNot(contains('hours')),
      );
    });

    test('includes the optional fields only when set', () {
      final full = VitalsQuery(
        metricSet: VitalsMetricSet.crashRate,
        metrics: const ['crashRate'],
        from: DateTime.utc(2026, 8, 2),
        to: DateTime.utc(2026, 8, 21),
        dimensions: const ['countryCode'],
        filter: 'versionCode = 1234',
        userCohort: UserCohort.appTesters,
        pageSize: 500,
      );

      final body = full.toRequestBody(pageToken: 'tok');
      expect(body['dimensions'], ['countryCode']);
      expect(body['filter'], 'versionCode = 1234');
      expect(body['userCohort'], 'APP_TESTERS');
      expect(body['pageSize'], 500);
      expect(body['pageToken'], 'tok');

      expect(_query().toRequestBody().keys, ['timelineSpec', 'metrics']);
    });
  });

  group('validation', () {
    test('errorCounts demands the reportType dimension', () {
      // Google's error for the missing dimension does not name it.
      expect(
        () => _query(
          metricSet: VitalsMetricSet.errorCounts,
          metrics: const ['errorReportCount'],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('reportType'),
          ),
        ),
      );

      expect(
        () => _query(
          metricSet: VitalsMetricSet.errorCounts,
          metrics: const ['errorReportCount'],
          dimensions: const ['reportType'],
        ),
        returnsNormally,
      );
    });

    test('no other metric set requires a dimension', () {
      for (final set in VitalsMetricSet.values) {
        if (set == VitalsMetricSet.errorCounts) continue;
        expect(set.requiredDimensions, isEmpty, reason: set.resourceId);
      }
    });

    test('rejects rolling averages at hourly granularity', () {
      // Google computes these daily and does not offer them hourly.
      expect(
        () => _query(
          metrics: const ['crashRate7dUserWeighted'],
          period: AggregationPeriod.hourly,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('7dUserWeighted'),
          ),
        ),
      );
      expect(
        () => _query(
          metrics: const ['crashRate28dUserWeighted'],
          period: AggregationPeriod.hourly,
        ),
        throwsArgumentError,
      );
    });

    test('allows rolling averages at daily granularity', () {
      expect(
        () => _query(metrics: const ['crashRate7dUserWeighted']),
        returnsNormally,
      );
    });

    test('allows a metric name this package does not know', () {
      // Google adds metrics without notice; a hard list would block one that
      // works. Same reasoning as SalesReportQuery's version handling.
      expect(
        () => _query(metrics: const ['someFutureMetric']),
        returnsNormally,
      );
    });

    test('rejects an empty metric list and a backwards period', () {
      expect(() => _query(metrics: const []), throwsArgumentError);
      expect(
        () => VitalsQuery(
          metricSet: VitalsMetricSet.crashRate,
          metrics: const ['crashRate'],
          from: DateTime.utc(2026, 8, 21),
          to: DateTime.utc(2026, 8, 2),
        ),
        throwsArgumentError,
      );
    });
  });

  group('VitalsMetricSet', () {
    test('builds the resource name Google addresses', () {
      expect(
        VitalsMetricSet.crashRate.resourceName('com.example.app'),
        'apps/com.example.app/crashRateMetricSet',
      );
      expect(
        VitalsMetricSet.errorCounts.resourceName('com.example.app'),
        'apps/com.example.app/errorCountMetricSet',
      );
    });

    test('distinctUsers is a count in every set, including rate sets', () {
      // Averaging it as if it were a rate would be nonsense.
      expect(
        VitalsMetricSet.crashRate.unitFor('distinctUsers'),
        MetricUnit.count,
      );
      expect(VitalsMetricSet.crashRate.unitFor('crashRate'), MetricUnit.rate);
      expect(
        VitalsMetricSet.bitmapMemoryUsage.unitFor('bitmapMemoryUsageP50'),
        MetricUnit.bytes,
      );
      expect(
        VitalsMetricSet.errorCounts.unitFor('errorReportCount'),
        MetricUnit.count,
      );
    });

    test('isRollingAverage matches both windows only', () {
      expect(VitalsMetricSet.isRollingAverage('crashRate7dUserWeighted'), true);
      expect(
        VitalsMetricSet.isRollingAverage('crashRate28dUserWeighted'),
        true,
      );
      expect(VitalsMetricSet.isRollingAverage('crashRate'), false);
    });
  });

  group('AggregationPeriod', () {
    test('daily buckets are Los Angeles days, not UTC ones', () {
      // Worth surfacing: a Play "day" and an App Store "day" cover different
      // 24-hour windows, and neither is a UTC day.
      expect(AggregationPeriod.daily.timeZoneId, 'America/Los_Angeles');
      expect(AggregationPeriod.hourly.timeZoneId, 'UTC');
      expect(AggregationPeriod.fullRange.timeZoneId, isNull);
    });

    test('only hourly lacks rolling averages', () {
      expect(AggregationPeriod.hourly.supportsRollingAverages, isFalse);
      expect(AggregationPeriod.daily.supportsRollingAverages, isTrue);
      expect(AggregationPeriod.fullRange.supportsRollingAverages, isTrue);
    });
  });
}
