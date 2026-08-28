import 'package:colaxy_store_console/src/app_store/analytics/analytics_enums.dart';
import 'package:colaxy_store_console/src/reports/report_row.dart';

/// A standing request for analytics reports on one app.
///
/// The first link in the chain: request → report → instance → segment.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: The resource ID, used to list the reports underneath it.
/// - **[accessType]**: Whether it backfills or keeps producing.
///
/// ### Optional
/// - **[stoppedDueToInactivity]**: Whether Apple has stopped it (default:
///   `false`).
class AnalyticsReportRequest {
  /// Creates a report request.
  const AnalyticsReportRequest({
    required this.id,
    required this.accessType,
    this.stoppedDueToInactivity = false,
  });

  /// Reads one `analyticsReportRequests` resource.
  factory AnalyticsReportRequest.fromJson(Map<String, dynamic> resource) {
    final attributes = resource['attributes'];
    final map = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    return AnalyticsReportRequest(
      id: resource['id'] as String? ?? '',
      accessType:
          AnalyticsAccessType.parse(map['accessType'] as String?) ??
          AnalyticsAccessType.ongoing,
      stoppedDueToInactivity: map['stoppedDueToInactivity'] as bool? ?? false,
    );
  }

  /// The resource ID.
  final String id;

  /// Whether it backfills history or keeps producing.
  final AnalyticsAccessType accessType;

  /// Whether Apple has stopped producing for this request.
  ///
  /// Apple deletes reports that go unused, and the request's IDs stop
  /// resolving with them. A stopped request cannot be restarted — a new one
  /// has to be created, and it comes with new IDs, so anything you stored
  /// pointing into the old one is dead too.
  final bool stoppedDueToInactivity;

  /// Whether this request is still producing data.
  bool get isLive => !stoppedDueToInactivity;

  @override
  String toString() =>
      'AnalyticsReportRequest($id, ${accessType.wireName}'
      '${stoppedDueToInactivity ? ', stopped' : ''})';
}

/// One named analytics report under a request.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: The resource ID, used to list its instances.
/// - **[name]**: Apple's report name, e.g. `App Store Discovery and
///   Engagement Standard`.
///
/// ### Optional
/// - **[category]**: Which family it belongs to (default: `null` when Apple
///   sends one this package does not model).
class AnalyticsReport {
  /// Creates a report.
  const AnalyticsReport({required this.id, required this.name, this.category});

  /// Reads one `analyticsReports` resource.
  factory AnalyticsReport.fromJson(Map<String, dynamic> resource) {
    final attributes = resource['attributes'];
    final map = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    return AnalyticsReport(
      id: resource['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      category: AnalyticsReportCategory.parse(map['category'] as String?),
    );
  }

  /// The resource ID.
  final String id;

  /// Apple's report name.
  ///
  /// These are prose, not identifiers, and Apple has renamed them. Filter on
  /// [category] where you can, and treat a name filter as brittle.
  final String name;

  /// Which family it belongs to.
  final AnalyticsReportCategory? category;

  @override
  String toString() =>
      'AnalyticsReport($id, "$name", ${category?.wireName ?? 'uncategorised'})';
}

/// One generated copy of a report, at one granularity for one date.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: The resource ID, used to list its segments.
///
/// ### Optional
/// - **[granularity]**: Bucket size (default: `null` when unrecognised).
/// - **[processingDate]**: The day Apple generated it (default: `null`).
class AnalyticsReportInstance {
  /// Creates a report instance.
  const AnalyticsReportInstance({
    required this.id,
    this.granularity,
    this.processingDate,
  });

  /// Reads one `analyticsReportInstances` resource.
  factory AnalyticsReportInstance.fromJson(Map<String, dynamic> resource) {
    final attributes = resource['attributes'];
    final map = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    return AnalyticsReportInstance(
      id: resource['id'] as String? ?? '',
      granularity: AnalyticsGranularity.parse(map['granularity'] as String?),
      processingDate: ReportRow.parseDate('${map['processingDate'] ?? ''}'),
    );
  }

  /// The resource ID.
  final String id;

  /// Bucket size.
  final AnalyticsGranularity? granularity;

  /// The day Apple generated this instance, as UTC midnight.
  final DateTime? processingDate;

  @override
  String toString() =>
      'AnalyticsReportInstance($id, ${granularity?.wireName ?? '?'}, '
      '${processingDate?.toIso8601String().split('T').first ?? '?'})';
}

/// One downloadable chunk of a report instance.
///
/// Apple splits a large instance across several segments; each is an
/// independent gzipped TSV **with its own header row**, and together they
/// make up the instance.
///
/// ## Parameters
///
/// ### Required
/// - **[id]**: The resource ID.
/// - **[url]**: A pre-signed download URL.
///
/// ### Optional
/// - **[checksum]**: Apple's checksum of the payload (default: `null`).
/// - **[sizeInBytes]**: Compressed size (default: `null`).
class AnalyticsReportSegment {
  /// Creates a report segment.
  const AnalyticsReportSegment({
    required this.id,
    required this.url,
    this.checksum,
    this.sizeInBytes,
  });

  /// Reads one `analyticsReportSegments` resource.
  factory AnalyticsReportSegment.fromJson(Map<String, dynamic> resource) {
    final attributes = resource['attributes'];
    final map = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    return AnalyticsReportSegment(
      id: resource['id'] as String? ?? '',
      url: map['url'] as String? ?? '',
      checksum: map['checksum'] as String?,
      sizeInBytes: map['sizeInBytes'] as int?,
    );
  }

  /// The resource ID.
  final String id;

  /// A pre-signed download URL.
  ///
  /// It points off the API host, carries its own credentials, and **expires**.
  /// Do not store it: re-list the segments when you are ready to download.
  final String url;

  /// Apple's checksum of the payload.
  final String? checksum;

  /// Compressed size in bytes.
  final int? sizeInBytes;

  @override
  String toString() => 'AnalyticsReportSegment($id, $sizeInBytes bytes)';
}
