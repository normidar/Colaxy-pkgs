import 'package:colaxy_store_console/src/reports/store_metric.dart';

/// Which Android vitals metric set to query.
///
/// Each is a singleton resource under the app, addressed as
/// `apps/{packageName}/{resourceId}`. The metric names listed here are the
/// ones Google documents; they are not enforced when building a query, since
/// Google adds metrics without notice and a hard check would block a metric
/// that works.
enum VitalsMetricSet {
  /// Crashes, normalised by distinct users.
  crashRate(
    'crashRateMetricSet',
    MetricUnit.rate,
    metrics: [
      'crashRate',
      'crashRate7dUserWeighted',
      'crashRate28dUserWeighted',
      'userPerceivedCrashRate',
      'userPerceivedCrashRate7dUserWeighted',
      'userPerceivedCrashRate28dUserWeighted',
      'distinctUsers',
    ],
  ),

  /// Application-not-responding events, normalised by distinct users.
  anrRate(
    'anrRateMetricSet',
    MetricUnit.rate,
    metrics: [
      'anrRate',
      'anrRate7dUserWeighted',
      'anrRate28dUserWeighted',
      'userPerceivedAnrRate',
      'userPerceivedAnrRate7dUserWeighted',
      'userPerceivedAnrRate28dUserWeighted',
      'distinctUsers',
    ],
  ),

  /// Raw error report counts, **not** normalised by users.
  ///
  /// Unlike every other set, this one requires the `reportType` dimension on
  /// every query.
  errorCounts(
    'errorCountMetricSet',
    MetricUnit.count,
    metrics: ['errorReportCount', 'distinctUsers'],
    requiredDimensions: {'reportType'},
  ),

  /// Wakeups beyond the allowance, normalised by distinct users.
  excessiveWakeupRate(
    'excessiveWakeupRateMetricSet',
    MetricUnit.rate,
    metrics: [
      'excessiveWakeupRate',
      'excessiveWakeupRate7dUserWeighted',
      'excessiveWakeupRate28dUserWeighted',
      'distinctUsers',
    ],
  ),

  /// Background wakelocks held too long, normalised by distinct users.
  stuckBackgroundWakelockRate(
    'stuckBackgroundWakelockRateMetricSet',
    MetricUnit.rate,
    metrics: [
      'stuckBgWakelockRate',
      'stuckBgWakelockRate7dUserWeighted',
      'stuckBgWakelockRate28dUserWeighted',
      'distinctUsers',
    ],
  ),

  /// Slow cold starts, normalised by distinct users.
  slowStartRate(
    'slowStartRateMetricSet',
    MetricUnit.rate,
    metrics: [
      'slowStartRate',
      'slowStartRate7dUserWeighted',
      'slowStartRate28dUserWeighted',
      'distinctUsers',
    ],
  ),

  /// Sessions rendering below 20 or 30 fps, normalised by distinct users.
  slowRenderingRate(
    'slowRenderingRateMetricSet',
    MetricUnit.rate,
    metrics: [
      'slowRenderingRate20Fps',
      'slowRenderingRate20Fps7dUserWeighted',
      'slowRenderingRate20Fps28dUserWeighted',
      'slowRenderingRate30Fps',
      'slowRenderingRate30Fps7dUserWeighted',
      'slowRenderingRate30Fps28dUserWeighted',
      'distinctUsers',
    ],
  ),

  /// Low-memory-killer terminations, normalised by distinct users.
  lmkRate(
    'lmkRateMetricSet',
    MetricUnit.rate,
    metrics: [
      'userPerceivedLmkRate',
      'userPerceivedLmkRate7dUserWeighted',
      'userPerceivedLmkRate28dUserWeighted',
      'distinctUsers',
    ],
  ),

  /// Bitmap memory held, at percentiles.
  bitmapMemoryUsage(
    'bitmapMemoryUsageMetricSet',
    MetricUnit.bytes,
    metrics: [
      'bitmapMemoryUsageP50',
      'bitmapMemoryUsageP75',
      'bitmapMemoryUsageP90',
      'bitmapMemoryUsageP95',
      'bitmapMemoryUsageP99',
      'distinctUsers',
    ],
  ),

  /// Anonymous RSS plus swap, at percentiles.
  anonRssAndSwapMemoryUsage(
    'anonRssAndSwapMemoryUsageMetricSet',
    MetricUnit.bytes,
    metrics: [
      'anonRssAndSwapMemoryUsageP50',
      'anonRssAndSwapMemoryUsageP75',
      'anonRssAndSwapMemoryUsageP90',
      'anonRssAndSwapMemoryUsageP95',
      'anonRssAndSwapMemoryUsageP99',
      'distinctUsers',
    ],
  );

  const VitalsMetricSet(
    this.resourceId,
    this.defaultUnit, {
    required this.metrics,
    this.requiredDimensions = const {},
  });

  /// The resource segment, e.g. `crashRateMetricSet`.
  final String resourceId;

  /// What most of this set's metrics measure.
  ///
  /// Read [unitFor] rather than this directly: every set also carries
  /// `distinctUsers`, which is a count whatever the rest of the set is.
  final MetricUnit defaultUnit;

  /// The metric names Google documents for this set.
  final List<String> metrics;

  /// Dimensions every query for this set must carry.
  ///
  /// Only [errorCounts] has any. Omitting `reportType` there fails with a
  /// message that does not say which dimension is missing.
  final Set<String> requiredDimensions;

  /// The resource name for [packageName], as Google addresses it.
  String resourceName(String packageName) => 'apps/$packageName/$resourceId';

  /// What [metric] measures.
  ///
  /// `distinctUsers` and any `…Count` metric are counts; everything else
  /// follows [defaultUnit].
  MetricUnit unitFor(String metric) {
    if (metric == 'distinctUsers' || metric.endsWith('Count')) {
      return MetricUnit.count;
    }
    return defaultUnit;
  }

  /// Whether [metric] is a rolling average, which Google computes daily only.
  static bool isRollingAverage(String metric) =>
      metric.endsWith('7dUserWeighted') || metric.endsWith('28dUserWeighted');
}
