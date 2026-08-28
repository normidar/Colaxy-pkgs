import 'package:colaxy_store_console/src/app_store/analytics/analytics_enums.dart';
import 'package:colaxy_store_console/src/app_store/analytics/analytics_models.dart';
import 'package:colaxy_store_console/src/app_store/app_store_connect_client.dart';
import 'package:colaxy_store_console/src/core/store.dart';
import 'package:colaxy_store_console/src/core/store_console_exception.dart';
import 'package:colaxy_store_console/src/reports/report_table.dart';

/// App Store Connect's analytics reports: impressions, product page views,
/// downloads by source, sessions, retention.
///
/// This is the one asynchronous surface in the package, and it is worth
/// understanding before writing against it. Nothing is queryable. You
/// register a standing *request*, Apple generates *reports* under it, each
/// report has dated *instances*, and each instance is split into
/// *segments* that hold the actual gzipped TSV:
///
/// ```text
/// request  →  report  →  instance  →  segment  →  gzip TSV
/// ```
///
/// The consequences are not incidental:
///
/// - **The first data arrives 24–48 hours after the request is created.**
///   Creating a request and reading it in the same job returns nothing. Split
///   the two: register once, collect on a schedule.
/// - **Instances expire, and unused requests are deleted.** Apple keeps
///   instances "for a limited period" and stops requests that go unread,
///   flagging them with `stoppedDueToInactivity`. Both mean stored IDs go
///   dead. Treat this as a pipeline that runs regularly and stores its own
///   copy, not as an API you query on demand.
/// - **Segment URLs are pre-signed and expire.** List them when you are ready
///   to download, not earlier.
/// - **Registering a request needs an Admin key.** Downloading afterwards
///   does not: once a report type has been requested for the app, a Sales or
///   Finance key can collect it. So [createRequest] and the rest of this API
///   may want different keys.
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: Transport to issue requests through.
/// - **[appId]**: The app's App Store Connect resource ID.
///
/// ## Example
///
/// ```dart
/// // Once, at setup.
/// await api.createRequest(AnalyticsAccessType.ongoing);
///
/// // Later, on a schedule.
/// final request = (await api.requests()).firstWhere((r) => r.isLive);
/// for (final report in await api.reports(request.id)) {
///   for (final instance in await api.instances(report.id)) {
///     final table = await api.downloadInstance(instance.id);
///   }
/// }
/// ```
class AnalyticsReportsApi {
  /// Creates an analytics client for one App Store app.
  AnalyticsReportsApi({
    required AppStoreConnectClient client,
    required this.appId,
  }) : _client = client;

  /// The app's App Store Connect resource ID.
  final String appId;

  final AppStoreConnectClient _client;

  /// Registers a standing request for [accessType].
  ///
  /// Data does not appear for 24–48 hours. Run this once at setup, not per
  /// collection.
  Future<AnalyticsReportRequest> createRequest(
    AnalyticsAccessType accessType,
  ) async {
    final json = await _client.postJson('/v1/analyticsReportRequests', {
      'data': {
        'type': 'analyticsReportRequests',
        'attributes': {'accessType': accessType.wireName},
        'relationships': {
          'app': {
            'data': {'type': 'apps', 'id': appId},
          },
        },
      },
    });

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const StoreApiException(
        'App Store Connect accepted the analytics request but returned no '
        'resource.',
        statusCode: 200,
        store: Store.appStore,
      );
    }
    return AnalyticsReportRequest.fromJson(data);
  }

  /// The standing requests registered for this app.
  ///
  /// Pass [accessType] to narrow to snapshots or ongoing requests.
  Future<List<AnalyticsReportRequest>> requests({
    AnalyticsAccessType? accessType,
  }) async {
    final resources = await _client
        .resources(
          '/v1/apps/$appId/analyticsReportRequests',
          query: {'filter[accessType]': accessType?.wireName},
        )
        .toList();
    return [for (final r in resources) AnalyticsReportRequest.fromJson(r)];
  }

  /// A live request of [accessType], registering one if there is none.
  ///
  /// Requests Apple has stopped are skipped: they produce nothing and their
  /// IDs no longer resolve.
  ///
  /// Note that Apple does not document what happens when a second request of
  /// the same access type is created for an app. This reuses a live one
  /// rather than finding out; if every existing request is stopped it does
  /// create a new one, and a rejection there surfaces as a
  /// [StoreApiException] naming Apple's reason.
  Future<AnalyticsReportRequest> ensureRequest(
    AnalyticsAccessType accessType,
  ) async {
    final existing = await requests(accessType: accessType);
    for (final request in existing) {
      if (request.isLive) return request;
    }
    return createRequest(accessType);
  }

  /// Deletes the request [requestId], and the reports underneath it.
  ///
  /// Apple stops generating for it and the IDs beneath stop resolving.
  Future<void> deleteRequest(String requestId) =>
      _client.delete('/v1/analyticsReportRequests/$requestId');

  /// The reports Apple generates under [requestId].
  ///
  /// [category] is the reliable filter. [name] exists too, but report names
  /// are prose that Apple has renamed before, so filtering on one is brittle.
  Future<List<AnalyticsReport>> reports(
    String requestId, {
    AnalyticsReportCategory? category,
    String? name,
  }) async {
    final resources = await _client
        .resources(
          '/v1/analyticsReportRequests/$requestId/reports',
          query: {
            'filter[category]': category?.wireName,
            'filter[name]': name,
          },
        )
        .toList();
    return [for (final r in resources) AnalyticsReport.fromJson(r)];
  }

  /// The generated instances of [reportId].
  ///
  /// [processingDate] filters to the day Apple generated an instance, which
  /// is not the same as the day the data covers.
  Future<List<AnalyticsReportInstance>> instances(
    String reportId, {
    AnalyticsGranularity? granularity,
    DateTime? processingDate,
  }) async {
    final resources = await _client
        .resources(
          '/v1/analyticsReports/$reportId/instances',
          query: {
            'filter[granularity]': granularity?.wireName,
            'filter[processingDate]': processingDate == null
                ? null
                : _date(processingDate),
          },
        )
        .toList();
    return [for (final r in resources) AnalyticsReportInstance.fromJson(r)];
  }

  /// The downloadable segments of [instanceId].
  ///
  /// Fetch these immediately before downloading: the URLs they carry are
  /// pre-signed and expire.
  Future<List<AnalyticsReportSegment>> segments(String instanceId) async {
    final resources = await _client
        .resources('/v1/analyticsReportInstances/$instanceId/segments')
        .toList();
    return [for (final r in resources) AnalyticsReportSegment.fromJson(r)];
  }

  /// Downloads one segment as a table.
  ///
  /// Throws [StoreApiException] if the URL has expired; re-list the segments
  /// and try the fresh URL.
  Future<ReportTable> downloadSegment(AnalyticsReportSegment segment) async {
    final bytes = await _client.getSignedBytes(Uri.parse(segment.url));
    return ReportTable.fromGzippedTsv(bytes);
  }

  /// Downloads every segment of [instanceId] and joins them into one table.
  ///
  /// Each segment is an independent file with its own header row; only the
  /// concatenation is the report. Segments are fetched in order and in
  /// sequence — they are large, and Apple throttles.
  ///
  /// Returns an empty table when the instance has no segments.
  Future<ReportTable> downloadInstance(String instanceId) async {
    final tables = <ReportTable>[];
    for (final segment in await segments(instanceId)) {
      tables.add(await downloadSegment(segment));
    }
    return ReportTable.concat(tables);
  }

  /// Releases the underlying HTTP client.
  void close() => _client.close();

  static String _date(DateTime date) {
    final utc = date.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }
}
