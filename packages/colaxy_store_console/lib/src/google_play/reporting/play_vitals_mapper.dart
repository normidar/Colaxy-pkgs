import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/google_play/reporting/aggregation_period.dart';
import 'package:colaxy_store_console/src/google_play/reporting/metric_freshness.dart';
import 'package:colaxy_store_console/src/google_play/reporting/vitals_metric_set.dart';
import 'package:colaxy_store_console/src/reports/metric_point.dart';
import 'package:colaxy_store_console/src/reports/store_metric.dart';

/// Turns Play Developer Reporting responses into this package's models.
///
/// Google returns one row per bucket-and-dimension-combination, each carrying
/// *several* metrics. This package's `StoreMetric` is one metric over time,
/// so the response has to be pivoted: every row contributes one point to each
/// of the metrics it carries.
abstract final class PlayVitalsMapper {
  /// Pivots `rows` into one [StoreMetric] per metric name.
  ///
  /// The result is keyed by metric name and holds only the metrics Google
  /// actually returned — asking for a metric that has no data yields no
  /// entry rather than an empty one, so a caller can tell "no data" from
  /// "zero".
  static Map<String, StoreMetric> metrics(
    Object? rows, {
    required VitalsMetricSet metricSet,
  }) {
    final points = <String, List<MetricPoint>>{};
    if (rows is! List) return const {};

    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;

      final date = dateTime(row['startTime']);
      if (date == null) continue;
      final dimensions = dimensionsOf(row['dimensions']);

      final values = row['metrics'];
      if (values is! List) continue;
      for (final entry in values) {
        if (entry is! Map<String, dynamic>) continue;
        final name = entry['metric'];
        if (name is! String) continue;
        final value = decimal(entry['decimalValue']);
        if (value == null) continue;

        (points[name] ??= <MetricPoint>[]).add(
          MetricPoint(date: date, value: value, dimensions: dimensions),
        );
      }
    }

    return {
      for (final entry in points.entries)
        entry.key: StoreMetric(
          store: Store.googlePlay,
          name: entry.key,
          unit: metricSet.unitFor(entry.key),
          points: entry.value,
        ),
    };
  }

  /// Reads a `google.type.DateTime` as the civil time Google reported.
  ///
  /// The fields are taken at face value and labelled UTC — deliberately.
  /// A `DAILY` bucket is a `America/Los_Angeles` calendar day, so shifting it
  /// into real UTC would move it off midnight and, at the edges, onto the
  /// wrong calendar date. Keeping "2026-08-20" meaning Google's 2026-08-20 is
  /// what matches Play Console, which is what anyone comparing the two wants.
  static DateTime? dateTime(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final year = _int(value['year']);
    final month = _int(value['month']);
    final day = _int(value['day']);
    if (year == null || month == null || day == null) return null;
    return DateTime.utc(
      year,
      month,
      day,
      _int(value['hours']) ?? 0,
      _int(value['minutes']) ?? 0,
      _int(value['seconds']) ?? 0,
    );
  }

  /// Reads a `google.type.Decimal`, which arrives as `{"value": "0.0231"}`.
  ///
  /// Parsed from the string rather than trusted as a number, because that is
  /// the only form Google sends it in.
  static num? decimal(Object? value) {
    if (value is num) return value;
    if (value is! Map<String, dynamic>) return null;
    final text = value['value'];
    if (text is num) return text;
    if (text is! String) return null;
    return num.tryParse(text.trim());
  }

  /// Reads a row's dimension values into a plain map.
  ///
  /// Google sends either `stringValue` or `int64Value`; the latter is a
  /// string because it is an int64. Both become strings here so a dimension
  /// key means the same thing whichever it was.
  static Map<String, String> dimensionsOf(Object? value) {
    if (value is! List) return const {};
    final dimensions = <String, String>{};
    for (final entry in value) {
      if (entry is! Map<String, dynamic>) continue;
      final name = entry['dimension'];
      if (name is! String) continue;
      final string = entry['stringValue'];
      final int64 = entry['int64Value'];
      if (string is String) {
        dimensions[name] = string;
      } else if (int64 != null) {
        dimensions[name] = '$int64';
      }
    }
    return dimensions;
  }

  /// Reads a metric set's `freshnessInfo`.
  static MetricFreshness freshness(Object? value) {
    if (value is! Map<String, dynamic>) return const MetricFreshness.unknown();
    final entries = value['freshnesses'];
    if (entries is! List) return const MetricFreshness.unknown();

    final latest = <AggregationPeriod, DateTime>{};
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      final period = periodOf(entry['aggregationPeriod'] as String?);
      final end = dateTime(entry['latestEndTime']);
      if (period == null || end == null) continue;
      latest[period] = end;
    }
    return MetricFreshness(latest);
  }

  /// Maps Google's aggregation period string onto [AggregationPeriod].
  ///
  /// An unrecognised value yields `null` rather than throwing: Google adds
  /// enum members without notice, and a new period is no reason to fail a
  /// whole freshness read.
  static AggregationPeriod? periodOf(String? value) => switch (value) {
    'HOURLY' => AggregationPeriod.hourly,
    'DAILY' => AggregationPeriod.daily,
    'FULL_RANGE' => AggregationPeriod.fullRange,
    _ => null,
  };

  static int? _int(Object? value) => switch (value) {
    final int value => value,
    final String value => int.tryParse(value),
    _ => null,
  };
}
