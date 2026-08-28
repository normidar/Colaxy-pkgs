import 'package:colaxy_store_console/src/google_play/reporting/aggregation_period.dart';
import 'package:colaxy_store_console/src/google_play/reporting/vitals_metric_set.dart';

/// Which users a vitals query covers.
enum UserCohort {
  /// Users on a public release. The default when unset.
  osPublic('OS_PUBLIC'),

  /// Users on an Android beta build.
  osBeta('OS_BETA'),

  /// Users on an internal, closed or open test track.
  appTesters('APP_TESTERS');

  const UserCohort(this.wireName);

  /// The value Google expects in `userCohort`.
  final String wireName;
}

/// One Android vitals query.
///
/// Two restrictions are checked here rather than left to Google, because its
/// errors for them do not name the cause:
///
/// - [VitalsMetricSet.errorCounts] requires the `reportType` dimension.
/// - Rolling averages (`…7dUserWeighted`, `…28dUserWeighted`) are daily
///   figures and are not available at [AggregationPeriod.hourly].
///
/// Metric *names* are not checked. Google adds metrics without notice, and a
/// hard list here would block one that works — the same reasoning as
/// `SalesReportQuery`'s version handling.
///
/// ## Parameters
///
/// ### Required
/// - **[metricSet]**: Which set to query.
/// - **[metrics]**: Metric names, e.g. `['crashRate', 'distinctUsers']`.
/// - **[from]** / **[to]**: The period, inclusive of [from] and exclusive of
///   [to].
///
/// ### Optional
/// - **[period]**: Bucket size (default: [AggregationPeriod.daily]).
/// - **[dimensions]**: Break the numbers down, e.g. `['countryCode']`
///   (default: empty, meaning totals).
/// - **[filter]**: Google's filter expression, e.g.
///   `versionCode = 1234` (default: `null`).
/// - **[userCohort]**: Which users (default: `null`, meaning public).
/// - **[pageSize]**: Rows per request (default: `null`, Google's choice).
///
/// ## Example
///
/// ```dart
/// final query = VitalsQuery(
///   metricSet: VitalsMetricSet.crashRate,
///   metrics: const ['userPerceivedCrashRate'],
///   from: DateTime.utc(2026, 8, 1),
///   to: DateTime.utc(2026, 8, 21),
/// );
/// ```
class VitalsQuery {
  /// Creates a vitals query, checking the restrictions above.
  VitalsQuery({
    required this.metricSet,
    required this.metrics,
    required this.from,
    required this.to,
    this.period = AggregationPeriod.daily,
    this.dimensions = const [],
    this.filter,
    this.userCohort,
    this.pageSize,
  }) {
    if (metrics.isEmpty) {
      throw ArgumentError.value(metrics, 'metrics', 'Cannot be empty');
    }
    if (!to.isAfter(from)) {
      throw ArgumentError.value(to, 'to', 'Must be after "from" ($from)');
    }

    final missing = metricSet.requiredDimensions.difference(dimensions.toSet());
    if (missing.isNotEmpty) {
      throw ArgumentError.value(
        dimensions,
        'dimensions',
        '${metricSet.resourceId} requires the '
            '${missing.join(', ')} dimension on every query',
      );
    }

    if (!period.supportsRollingAverages) {
      final rolling = metrics.where(VitalsMetricSet.isRollingAverage).toList();
      if (rolling.isNotEmpty) {
        throw ArgumentError.value(
          metrics,
          'metrics',
          '${rolling.join(', ')} are daily rolling averages and are not '
              'available at ${period.wireName} granularity',
        );
      }
    }
  }

  /// Which set to query.
  final VitalsMetricSet metricSet;

  /// Metric names to fetch.
  final List<String> metrics;

  /// Start of the period, inclusive.
  final DateTime from;

  /// End of the period, exclusive.
  final DateTime to;

  /// Bucket size.
  final AggregationPeriod period;

  /// Dimensions to break the numbers down by.
  final List<String> dimensions;

  /// Google's filter expression.
  final String? filter;

  /// Which users the numbers cover.
  final UserCohort? userCohort;

  /// Rows per request.
  final int? pageSize;

  /// The JSON body for `…MetricSet:query`.
  ///
  /// [pageToken] continues a previous response; the caller normally lets
  /// `PlayVitalsApi.query` handle paging.
  Map<String, dynamic> toRequestBody({String? pageToken}) => {
    'timelineSpec': {
      'aggregationPeriod': period.wireName,
      'startTime': _dateTime(from),
      'endTime': _dateTime(to),
    },
    'metrics': metrics,
    if (dimensions.isNotEmpty) 'dimensions': dimensions,
    'filter': ?filter,
    if (userCohort != null) 'userCohort': userCohort!.wireName,
    if (pageSize != null) 'pageSize': pageSize,
    'pageToken': ?pageToken,
  };

  /// Encodes [moment] as a `google.type.DateTime`.
  ///
  /// Hours are sent only for [AggregationPeriod.hourly]. A daily boundary
  /// carrying an hour is rejected, and the message does not say so.
  Map<String, dynamic> _dateTime(DateTime moment) {
    final utc = moment.toUtc();
    return {
      'year': utc.year,
      'month': utc.month,
      'day': utc.day,
      if (period == AggregationPeriod.hourly) 'hours': utc.hour,
    };
  }

  @override
  String toString() =>
      'VitalsQuery(${metricSet.resourceId}, ${metrics.join(', ')}, '
      '${period.wireName})';
}
