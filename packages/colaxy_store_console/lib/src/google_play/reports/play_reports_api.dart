import 'package:colaxy_store_console/src/google_play/reports/play_report_type.dart';
import 'package:colaxy_store_console/src/google_play/reports/play_storage_client.dart';
import 'package:colaxy_store_console/src/reports/report_table.dart';

/// Downloads Google Play's monthly report CSVs from the developer's Cloud
/// Storage bucket.
///
/// This is the only route to installs, ratings, store performance and review
/// history: Google publishes none of them through an API. It is also the only
/// route to a real rating average, since the reviews API omits ratings that
/// carry no text.
///
/// ## Getting the bucket ID
///
/// In **Play Console → Download reports**, each section has a *Copy Cloud
/// Storage URI* button giving something like
/// `gs://pubsite_prod_1234567898765432100/stats/installs/`. The bucket is
/// the `pubsite_prod_…` part — paste the whole URI if you like, it is
/// trimmed for you. It is per developer account, appears in no API, and so
/// has to be configured.
///
/// The service account needs `PlayServiceAccount.storageReadScope` *and* to
/// be invited in Play Console — the same two-step setup as the reviews API,
/// and the same failure mode when the second step is missed.
///
/// ## Parameters
///
/// ### Required
/// - **`client`**: Transport to issue requests through.
/// - **[bucket]**: The `pubsite_prod_…` bucket ID or a copied `gs://` URI.
/// - **[packageName]**: The app's application ID.
///
/// ## Example
///
/// ```dart
/// final api = PlayReportsApi(
///   client: PlayStorageClient(
///     authenticatedClient: await account.authenticate(
///       scopes: [PlayServiceAccount.storageReadScope],
///     ),
///   ),
///   bucket: 'pubsite_prod_1234567898765432100',
///   packageName: 'com.example.app',
/// );
///
/// final table = await api.fetch(
///   PlayReportType.installs,
///   month: DateTime.utc(2026, 8),
///   dimension: 'country',
/// );
/// ```
class PlayReportsApi {
  /// Creates a reports client for one app's bucket.
  PlayReportsApi({
    required PlayStorageClient client,
    required String bucket,
    required this.packageName,
  }) : bucket = normaliseBucket(bucket),
       _client = client;

  /// The bucket ID, without any `gs://` scheme or trailing path.
  final String bucket;

  /// The app's application ID.
  final String packageName;

  final PlayStorageClient _client;

  /// Strips the `gs://` scheme and any path from a copied Cloud Storage URI.
  ///
  /// Play Console's copy button hands over
  /// `gs://pubsite_prod_…/stats/installs/`, and passing that whole string
  /// as a bucket name fails with an error about an invalid bucket.
  static String normaliseBucket(String bucket) {
    var value = bucket.trim();
    if (value.startsWith('gs://')) value = value.substring(5);
    final slash = value.indexOf('/');
    return slash == -1 ? value : value.substring(0, slash);
  }

  /// Downloads one monthly report as a table.
  ///
  /// Returns an **empty table with no columns** when Google has published no
  /// such file — a month with no data, or one not published yet. As with
  /// Apple's zero-sales `404`, that is an answer rather than a failure, and a
  /// report that does exist always carries a header row.
  ///
  /// Throws [ArgumentError] before any request when [dimension] is not a
  /// breakdown Google publishes for [type].
  Future<ReportTable> fetch(
    PlayReportType type, {
    required DateTime month,
    String? dimension,
  }) => fetchObject(
    type.objectName(
      packageName: packageName,
      month: month,
      dimension: dimension,
    ),
  );

  /// Downloads every published month of [type], oldest first.
  ///
  /// Discovers the months by listing rather than guessing, so it does not
  /// depend on knowing when the app was published or on Google's timing —
  /// which Google explicitly says not to depend on.
  ///
  /// Sequential on purpose: a long-lived app has years of files, and firing
  /// them all at once is the quickest way to be throttled.
  ///
  /// Throws [ArgumentError] under the same rules as [fetch]: a report that is
  /// published per breakdown needs one naming which. Without that this would
  /// stream every breakdown of every month interleaved — tables with
  /// different columns, in one stream, which is nearly impossible to notice
  /// and impossible to use.
  Stream<ReportTable> fetchAll(
    PlayReportType type, {
    String? dimension,
  }) async* {
    // Validate up front, with the same message fetch would give, rather than
    // after the listing request has already been spent.
    type.objectName(
      packageName: packageName,
      month: DateTime.utc(2000),
      dimension: dimension,
    );

    final suffix = dimension == null ? '.csv' : '_$dimension.csv';
    for (final name in await list(type)) {
      if (!name.endsWith(suffix)) continue;
      yield await fetchObject(name);
    }
  }

  /// Downloads any object in the bucket by name, as a table.
  ///
  /// The escape hatch for reports this package does not model — subscriptions
  /// and buyer acquisition have their own file-name grammars.
  Future<ReportTable> fetchObject(String objectName) async {
    final bytes = await _client.download(bucket, objectName);
    if (bytes == null) return ReportTable.empty();
    return ReportTable.fromCsvBytes(bytes);
  }

  /// The object names Google has published for [type], oldest first.
  ///
  /// Prefer this over guessing month names: it says which months exist rather
  /// than returning a `404` you have to interpret.
  Future<List<String>> list(PlayReportType type) =>
      _client.list(bucket, prefix: type.objectPrefix(packageName));

  /// Releases the underlying HTTP client.
  void close() => _client.close();
}
