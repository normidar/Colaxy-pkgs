/// A monthly report Google Play drops in the developer's Cloud Storage
/// bucket.
///
/// These exist because **there is no API for them**. Installs, ratings and
/// store performance are not in the Play Developer API and not in the Play
/// Developer Reporting API; Google publishes them only as CSV files. That is
/// also why the numbers here cannot be reconciled with
/// `PlayReviewsApi` — the reviews CSV covers a whole month, while the reviews
/// API only reaches back seven days.
///
/// Each report is one file per month per breakdown, named
/// `{prefix}/{fileStem}_{packageName}_{yyyyMM}_{dimension}.csv`, except
/// [reviews], which has no breakdown.
enum PlayReportType {
  /// Installs, uninstalls, upgrades and active devices.
  installs(
    'stats/installs',
    'installs',
    dimensions: {
      'overview',
      'app_version',
      'carrier',
      'country',
      'device',
      'language',
      'os_version',
    },
  ),

  /// Daily and total star ratings.
  ///
  /// This is where a real rating average comes from. `StoreReview.rating`
  /// from the reviews API cannot give you one, because Google's review API
  /// omits ratings that carry no text.
  ratings(
    'stats/ratings',
    'ratings',
    dimensions: {
      'overview',
      'app_version',
      'carrier',
      'country',
      'device',
      'language',
      'os_version',
    },
  ),

  /// Crash and ANR counts, un-normalised.
  ///
  /// Android vitals normalises the same events by user count; these are raw
  /// tallies, so the two will not agree and are not meant to.
  crashes(
    'stats/crashes',
    'crashes',
    dimensions: {'overview', 'app_version', 'device', 'os_version'},
  ),

  /// Store listing visitors and acquisitions.
  ///
  /// Note there is no `overview` breakdown for this one.
  storePerformance(
    'stats/store_performance',
    'store_performance',
    dimensions: {'country', 'traffic_source'},
  ),

  /// Every review left in the month, with its text and the developer reply.
  ///
  /// Unlike the reviews API this is not limited to the last seven days, and
  /// it is the only way to get review history out of Google.
  reviews('reviews', 'reviews', dimensions: {});

  const PlayReportType(
    this.prefix,
    this.fileStem, {
    required this.dimensions,
  });

  /// The object-name prefix, e.g. `stats/installs`.
  final String prefix;

  /// The leading token of each file name, e.g. `installs`.
  final String fileStem;

  /// Breakdowns Google publishes, or empty when the report has none.
  ///
  /// Not every report offers the same set — [crashes] has no `carrier`,
  /// [storePerformance] has no `overview` — and asking for one that does not
  /// exist is a `404` that reads like a missing month.
  final Set<String> dimensions;

  /// Whether this report is published per breakdown.
  bool get hasDimensions => dimensions.isNotEmpty;

  /// The object name for [packageName] in [month], optionally broken down.
  ///
  /// [month] is used for its year and month only; the day is ignored.
  ///
  /// Throws [ArgumentError] when [dimension] is missing for a report that
  /// needs one, supplied for [reviews] which has none, or not a breakdown
  /// Google publishes for this report.
  String objectName({
    required String packageName,
    required DateTime month,
    String? dimension,
  }) {
    if (!hasDimensions) {
      if (dimension != null) {
        throw ArgumentError.value(
          dimension,
          'dimension',
          '$name reports have no breakdowns',
        );
      }
      return '$prefix/${fileStem}_${packageName}_${_month(month)}.csv';
    }
    if (dimension == null) {
      throw ArgumentError.notNull('dimension');
    }
    if (!dimensions.contains(dimension)) {
      throw ArgumentError.value(
        dimension,
        'dimension',
        'Google publishes no "$dimension" breakdown for $name. Available: '
            '${(dimensions.toList()..sort()).join(', ')}.',
      );
    }
    return '$prefix/${fileStem}_${packageName}_${_month(month)}_'
        '$dimension.csv';
  }

  /// The object-name prefix for every file of this report for [packageName].
  ///
  /// Use it with `PlayReportsApi.list` to discover which months exist rather
  /// than guessing and reading a `404`.
  String objectPrefix(String packageName) => '$prefix/${fileStem}_$packageName';

  static String _month(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}'
      '${month.month.toString().padLeft(2, '0')}';
}
