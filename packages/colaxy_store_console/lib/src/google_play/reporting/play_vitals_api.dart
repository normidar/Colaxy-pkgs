import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/google_play/reporting/metric_freshness.dart';
import 'package:colaxy_store_console/src/google_play/reporting/play_reporting_client.dart';
import 'package:colaxy_store_console/src/google_play/reporting/play_vitals_mapper.dart';
import 'package:colaxy_store_console/src/google_play/reporting/vitals_metric_set.dart';
import 'package:colaxy_store_console/src/google_play/reporting/vitals_query.dart';
import 'package:colaxy_store_console/src/reports/metric_point.dart';
import 'package:colaxy_store_console/src/reports/store_metric.dart';

/// Reads Android vitals for one app.
///
/// This is the closest Google has to a statistics API. What it does *not*
/// cover is worth knowing up front: installs, ratings and revenue are not
/// here — Google publishes those only as CSVs in a Cloud Storage bucket.
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: Transport to issue requests through, authenticated with
///   `PlayServiceAccount.reportingScope`.
/// - **[packageName]**: The app's application ID, e.g. `com.example.app`.
///
/// ## Example
///
/// ```dart
/// final metrics = await api.query(
///   VitalsQuery(
///     metricSet: VitalsMetricSet.crashRate,
///     metrics: const ['userPerceivedCrashRate'],
///     from: DateTime.utc(2026, 8, 1),
///     to: DateTime.utc(2026, 8, 21),
///   ),
/// );
/// print(metrics['userPerceivedCrashRate']?.average);
/// ```
class PlayVitalsApi {
  /// Creates a vitals client for one Google Play app.
  PlayVitalsApi({
    required PlayReportingClient client,
    required this.packageName,
  }) : _client = client;

  /// The app's application ID.
  final String packageName;

  final PlayReportingClient _client;

  /// Runs [query], following pagination, and pivots the rows into metrics.
  ///
  /// The result is keyed by metric name. A metric Google returned no rows for
  /// is absent rather than empty, so "no data" and "zero" stay distinct.
  ///
  /// This may issue several requests: Google pages the rows, and a query
  /// broken down by a high-cardinality dimension such as `deviceModel`
  /// produces a lot of them.
  Future<Map<String, StoreMetric>> query(VitalsQuery query) async {
    final rows = <Object?>[];
    String? pageToken;

    do {
      final response = await _client.postJson(
        '${query.metricSet.resourceName(packageName)}:query',
        query.toRequestBody(pageToken: pageToken),
      );
      final page = response['rows'];
      if (page is List) rows.addAll(page);
      final next = response['nextPageToken'];
      pageToken = next is String && next.isNotEmpty ? next : null;
    } while (pageToken != null);

    return PlayVitalsMapper.metrics(rows, metricSet: query.metricSet);
  }

  /// Runs [query] and returns just [metric], or an empty series if absent.
  ///
  /// A convenience for the common single-metric case. The empty series still
  /// carries the right store, name and unit, so callers can chart it without
  /// branching.
  Future<StoreMetric> queryOne(VitalsQuery query, String metric) async {
    final metrics = await this.query(query);
    return metrics[metric] ??
        StoreMetric(
          store: Store.googlePlay,
          name: metric,
          unit: query.metricSet.unitFor(metric),
          points: const <MetricPoint>[],
        );
  }

  /// How far forward [metricSet]'s data is settled.
  ///
  /// Read this before querying up to the present: recent buckets are still
  /// moving, and storing them as final is how a pipeline ends up disagreeing
  /// with Play Console.
  Future<MetricFreshness> freshness(VitalsMetricSet metricSet) async {
    final response = await _client.getJson(metricSet.resourceName(packageName));
    return PlayVitalsMapper.freshness(response['freshnessInfo']);
  }

  /// Releases the underlying HTTP client.
  void close() => _client.close();
}
