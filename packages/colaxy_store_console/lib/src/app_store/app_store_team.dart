import 'package:colaxy_store_console/src/app_store/app_store_api_key.dart';
import 'package:colaxy_store_console/src/app_store/app_store_connect_client.dart';
import 'package:colaxy_store_console/src/app_store/sales/sales_reports_api.dart';
import 'package:colaxy_store_console/src/core/retry_policy.dart';
import 'package:colaxy_store_console/src/core/store_console_log.dart';
import 'package:http/http.dart' as http;

/// Entry point for an App Store Connect **team**, as opposed to one app.
///
/// This exists because Apple scopes its two halves differently. Reviews are
/// per-app and keyed by an app resource ID; Sales and Trends reports are per
/// account and keyed by a *vendor number*, cover every app at once, and
/// cannot be narrowed to one app by the API. Hanging sales reports off
/// `AppStoreConnectConsole` would have implied a filter that does not exist.
///
/// A team and a console can share one [AppStoreConnectClient], and normally
/// should — that shares the connection pool and the cached bearer token.
///
/// ## Parameters
///
/// ### Required
/// - **`apiKey`**: The App Store Connect API key to authenticate with.
/// - **[vendorNumber]**: From **App Store Connect → Payments and Financial
///   Reports**, shown above the report list. The API has no endpoint that
///   returns it, so it has to be configured.
///
/// ### Optional
/// - **`httpClient`**: Transport to use (default: a new client this object
///   owns and closes).
/// - **`baseUri`**: API root (default:
///   `https://api.appstoreconnect.apple.com/`).
/// - **`retryPolicy`**: When to retry a throttled or transiently failing
///   request (default: `RetryPolicy()`, three attempts).
/// - **`onLog`**: Receives one line per retry and wait (default: `null`).
///
/// ## Example
///
/// ```dart
/// final team = AppStoreTeam(apiKey: key, vendorNumber: '85000000');
/// final table = await team.salesReports.fetch(
///   SalesReportQuery.sales(date: DateTime.utc(2026, 8, 20)),
/// );
/// team.close();
/// ```
class AppStoreTeam {
  /// Creates a team client.
  factory AppStoreTeam({
    required AppStoreApiKey apiKey,
    required String vendorNumber,
    http.Client? httpClient,
    Uri? baseUri,
    RetryPolicy retryPolicy = const RetryPolicy(),
    StoreConsoleLog? onLog,
  }) => AppStoreTeam.client(
    client: AppStoreConnectClient(
      apiKey: apiKey,
      httpClient: httpClient,
      baseUri: baseUri,
      retryPolicy: retryPolicy,
      onLog: onLog,
    ),
    vendorNumber: vendorNumber,
  );

  /// Creates a team client around an existing [AppStoreConnectClient].
  ///
  /// Use this to share one transport — and so one cached token — with an
  /// `AppStoreConnectConsole` for the same account.
  AppStoreTeam.client({
    required AppStoreConnectClient client,
    required this.vendorNumber,
  }) : _client = client,
       salesReports = SalesReportsApi(
         client: client,
         vendorNumber: vendorNumber,
       );

  /// The team's vendor number.
  final String vendorNumber;

  /// Sales and Trends reports for this account.
  final SalesReportsApi salesReports;

  final AppStoreConnectClient _client;

  /// The underlying transport, for calls this package does not wrap yet.
  AppStoreConnectClient get client => _client;

  /// Releases the HTTP client.
  void close() => _client.close();
}
