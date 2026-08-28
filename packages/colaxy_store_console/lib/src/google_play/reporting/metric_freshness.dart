import 'package:colaxy_store_console/src/google_play/reporting/aggregation_period.dart';

/// How far forward a metric set's data is settled, per aggregation period.
///
/// Vitals arrive late and arrive incomplete. Querying up to today returns
/// rows whose numbers are still moving, and a job that stores them as final
/// will disagree with Play Console tomorrow. Reading the freshness first and
/// clamping the query's end to [latestEndTimeFor] avoids that.
///
/// ## Parameters
///
/// ### Required
/// - **[latestEndTimes]**: The newest settled bucket end per period.
///
/// ## Example
///
/// ```dart
/// final freshness = await api.freshness(VitalsMetricSet.crashRate);
/// final until = freshness.latestEndTimeFor(AggregationPeriod.daily);
/// ```
class MetricFreshness {
  /// Creates a freshness record.
  const MetricFreshness(this.latestEndTimes);

  /// A record reporting nothing, for a set Google has no freshness for yet.
  const MetricFreshness.unknown() : latestEndTimes = const {};

  /// The newest settled bucket end per aggregation period.
  final Map<AggregationPeriod, DateTime> latestEndTimes;

  /// The newest settled bucket end for [period], or `null` if unreported.
  DateTime? latestEndTimeFor(AggregationPeriod period) =>
      latestEndTimes[period];

  /// Whether Google reported nothing at all.
  bool get isEmpty => latestEndTimes.isEmpty;

  /// Clamps [end] to what [period] has settled data for.
  ///
  /// Returns [end] unchanged when Google reported no freshness for that
  /// period — refusing to fetch on missing metadata would be worse than
  /// fetching data that might still move.
  DateTime clamp(DateTime end, AggregationPeriod period) {
    final latest = latestEndTimeFor(period);
    if (latest == null) return end;
    return end.isAfter(latest) ? latest : end;
  }

  @override
  String toString() =>
      'MetricFreshness(${latestEndTimes.entries.map((e) => '${e.key.wireName}: '
          '${e.value.toIso8601String()}').join(', ')})';
}
