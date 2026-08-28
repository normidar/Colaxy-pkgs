import 'package:colaxy_store_console/src/app_store/app_store_connect_client.dart';
import 'package:colaxy_store_console/src/app_store/sales/sales_report_query.dart';
import 'package:colaxy_store_console/src/core/store_console_exception.dart';
import 'package:colaxy_store_console/src/reports/report_table.dart';

/// Downloads App Store Connect's Sales and Trends reports.
///
/// These are **team-scoped**, not app-scoped: one report covers every app
/// under the account, keyed by SKU, and the API offers no way to ask for a
/// single app. Filter by SKU after the fact if you need one app's numbers.
///
/// Reports are cut on a schedule and are not available immediately: daily the
/// following day, weekly on Mondays, monthly five days after the month ends,
/// yearly six days after the year ends — generally by 08:00 Pacific. Apple
/// keeps daily, weekly and monthly reports for one year and yearly reports
/// for ten, and does not regenerate them afterwards.
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: Transport to issue requests through.
/// - **[vendorNumber]**: The team's vendor number, from **App Store Connect →
///   Payments and Financial Reports**. The API has no endpoint that lists it.
///
/// ## Example
///
/// ```dart
/// final table = await api.fetch(
///   SalesReportQuery.sales(date: DateTime.utc(2026, 8, 20)),
/// );
/// final units = table.entries.fold(0, (n, r) => n + (r.intAt('Units') ?? 0));
/// ```
class SalesReportsApi {
  /// Creates a sales reports client for one vendor number.
  SalesReportsApi({
    required AppStoreConnectClient client,
    required this.vendorNumber,
  }) : _client = client;

  /// The content type Apple serves reports as.
  static const gzipContentType = 'application/a-gzip';

  /// The team's vendor number.
  final String vendorNumber;

  final AppStoreConnectClient _client;

  /// Downloads the report [query] describes.
  ///
  /// Returns an **empty table with no columns** when Apple has no report for
  /// that period. That is a real answer, not a failure: a day with no sales
  /// answers `404` with "There were no sales for the date specified", and a
  /// job that treated it as an error would break every quiet day. A report
  /// that exists always has a header row, so `table.columns.isEmpty`
  /// distinguishes the two unambiguously.
  ///
  /// Throws [StoreApiException] for any other failure, and [ArgumentError]
  /// before any request if [query] describes a report Apple does not offer.
  Future<ReportTable> fetch(SalesReportQuery query) async {
    try {
      final bytes = await _client.getBytes(
        '/v1/salesReports',
        query: query.toFilters(vendorNumber: vendorNumber),
        accept: gzipContentType,
      );
      return ReportTable.fromGzippedTsv(bytes);
    } on StoreApiException catch (error) {
      if (error.statusCode == 404) return ReportTable.empty();
      rethrow;
    }
  }

  /// Downloads the reports for [queries], in order.
  ///
  /// Periods with no data yield empty tables rather than being skipped, so
  /// the result lines up one-to-one with [queries]. Sequential on purpose:
  /// firing a month of daily reports in parallel is the quickest way to meet
  /// Apple's throttling.
  Stream<ReportTable> fetchAll(Iterable<SalesReportQuery> queries) async* {
    for (final query in queries) {
      yield await fetch(query);
    }
  }

  /// Releases the underlying HTTP client.
  void close() => _client.close();
}
