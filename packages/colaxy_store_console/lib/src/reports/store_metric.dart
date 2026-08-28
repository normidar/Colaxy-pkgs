import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/reports/metric_point.dart';

/// What a metric's values mean, and therefore how they may be combined.
///
/// Getting this wrong is the usual way statistics code produces confident
/// nonsense — summing a crash *rate* across a month yields a number with no
/// meaning at all.
enum MetricUnit {
  /// A tally: installs, units sold, crashes. Summing is meaningful.
  count,

  /// A proportion, normally 0–1: crash rate, ANR rate. Averaging is
  /// meaningful; summing is not.
  rate,

  /// An amount of money, in the metric's currency. Summing is meaningful only
  /// within one currency.
  currency,

  /// A length of time, in milliseconds.
  duration,

  /// The store did not say, or this package does not model it yet.
  unknown,
}

/// One named measurement over time, from one store.
///
/// This is the only shape shared across all four statistics surfaces, and it
/// is deliberately the *only* thing they share. The surfaces differ in
/// granularity, freshness and even in which account they authenticate as, so
/// a common client interface over them would collapse to their least common
/// denominator. A common data shape does not.
///
/// A metric holds either totals or a breakdown, never both, so [total] and
/// [average] cannot double-count.
///
/// ## Parameters
///
/// ### Required
/// - **[store]**: Which store the numbers came from.
/// - **[name]**: Metric identifier, e.g. `crashRate` or `units`.
/// - **[points]**: The measurements.
///
/// ### Optional
/// - **[unit]**: What the values mean (default: [MetricUnit.unknown]).
/// - **[currency]**: ISO 4217 code, when [unit] is [MetricUnit.currency]
///   (default: `null`).
///
/// ## Example
///
/// ```dart
/// final japan = metric.whereDimension('countryCode', 'JPN');
/// print('${japan.total} units in Japan');
/// ```
class StoreMetric {
  /// Creates a metric series.
  const StoreMetric({
    required this.store,
    required this.name,
    required this.points,
    this.unit = MetricUnit.unknown,
    this.currency,
  });

  /// Which store the numbers came from.
  final Store store;

  /// Metric identifier.
  final String name;

  /// The measurements, in whatever order they were built.
  ///
  /// Use [sortedByDate] when order matters; neither store promises one.
  final List<MetricPoint> points;

  /// What the values mean.
  final MetricUnit unit;

  /// ISO 4217 code, when [unit] is [MetricUnit.currency].
  final String? currency;

  /// Whether there are no measurements.
  bool get isEmpty => points.isEmpty;

  /// Whether there is at least one measurement.
  bool get isNotEmpty => points.isNotEmpty;

  /// The sum of every value.
  ///
  /// Meaningful for [MetricUnit.count] and, within one currency, for
  /// [MetricUnit.currency]. Summing a [MetricUnit.rate] gives a number with
  /// no interpretation — use [average] there.
  num get total => points.fold<num>(0, (sum, point) => sum + point.value);

  /// The mean value, or `null` when there are no measurements.
  ///
  /// This is an unweighted mean over points. For a rate the store reports per
  /// day, that is the average daily rate, not the rate over the whole period
  /// — those differ whenever daily traffic does.
  double? get average => points.isEmpty ? null : total / points.length;

  /// The measurement with the latest date, or `null` when there are none.
  MetricPoint? get latest {
    if (points.isEmpty) return null;
    return points.reduce(
      (a, b) => b.date.isAfter(a.date) ? b : a,
    );
  }

  /// The earliest and latest dates covered, or `null` when there are none.
  ({DateTime from, DateTime to})? get period {
    if (points.isEmpty) return null;
    var from = points.first.date;
    var to = points.first.date;
    for (final point in points) {
      if (point.date.isBefore(from)) from = point.date;
      if (point.date.isAfter(to)) to = point.date;
    }
    return (from: from, to: to);
  }

  /// This metric with its points ordered oldest first.
  StoreMetric sortedByDate() => copyWith(
    points: [...points]..sort((a, b) => a.date.compareTo(b.date)),
  );

  /// This metric narrowed to points whose [key] dimension equals [value].
  ///
  /// Points with no such dimension are dropped, so filtering a metric of
  /// totals yields an empty metric rather than the totals unchanged.
  StoreMetric whereDimension(String key, String value) => copyWith(
    points: [
      for (final point in points)
        if (point.dimensions[key] == value) point,
    ],
  );

  /// Values summed per date.
  ///
  /// Use it to collapse a breakdown into a daily series. As with [total],
  /// this only means something for [MetricUnit.count] and
  /// [MetricUnit.currency].
  Map<DateTime, num> get byDate {
    final totals = <DateTime, num>{};
    for (final point in points) {
      totals[point.date] = (totals[point.date] ?? 0) + point.value;
    }
    return totals;
  }

  /// A copy of this metric with the given fields replaced.
  StoreMetric copyWith({
    Store? store,
    String? name,
    List<MetricPoint>? points,
    MetricUnit? unit,
    String? currency,
  }) => StoreMetric(
    store: store ?? this.store,
    name: name ?? this.name,
    points: points ?? this.points,
    unit: unit ?? this.unit,
    currency: currency ?? this.currency,
  );

  @override
  String toString() =>
      'StoreMetric(${store.displayName} $name, ${points.length} points, '
      '${unit.name})';
}
