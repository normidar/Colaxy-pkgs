/// Whether a report request backfills history or keeps producing new data.
///
/// Running both is the usual pattern: a snapshot to backfill, an ongoing
/// request to keep up.
enum AnalyticsAccessType {
  /// Every day of history Apple holds, produced once.
  ///
  /// Covers the app's creation up to the day the request was made, and does
  /// not update afterwards.
  oneTimeSnapshot('ONE_TIME_SNAPSHOT'),

  /// Daily, weekly and monthly reports from now on.
  ///
  /// The first data lands roughly 24–48 hours after the request is created,
  /// so this is not something to await inside a job.
  ongoing('ONGOING');

  const AnalyticsAccessType(this.wireName);

  /// The value Apple expects in `accessType`.
  final String wireName;

  /// Maps Apple's string, or `null` if it is one this package does not model.
  static AnalyticsAccessType? parse(String? value) => switch (value) {
    'ONE_TIME_SNAPSHOT' => oneTimeSnapshot,
    'ONGOING' => ongoing,
    _ => null,
  };
}

/// Which family of analytics a report belongs to.
enum AnalyticsReportCategory {
  /// Sessions, active devices, installs, deletions.
  appUsage('APP_USAGE'),

  /// Impressions, product page views, downloads by source.
  appStoreEngagement('APP_STORE_ENGAGEMENT'),

  /// Purchases, proceeds, subscription events.
  commerce('COMMERCE'),

  /// Which system frameworks the app uses.
  frameworkUsage('FRAMEWORK_USAGE'),

  /// Launch times, hangs, disk and memory.
  performance('PERFORMANCE');

  const AnalyticsReportCategory(this.wireName);

  /// The value Apple expects in `filter[category]`.
  final String wireName;

  /// Maps Apple's string, or `null` if it is one this package does not model.
  static AnalyticsReportCategory? parse(String? value) {
    for (final category in values) {
      if (category.wireName == value) return category;
    }
    return null;
  }
}

/// How an analytics report instance buckets its rows.
enum AnalyticsGranularity {
  /// One row set per day.
  daily('DAILY'),

  /// One row set per week.
  weekly('WEEKLY'),

  /// One row set per month.
  monthly('MONTHLY');

  const AnalyticsGranularity(this.wireName);

  /// The value Apple expects in `filter[granularity]`.
  final String wireName;

  /// Maps Apple's string, or `null` if it is one this package does not model.
  static AnalyticsGranularity? parse(String? value) {
    for (final granularity in values) {
      if (granularity.wireName == value) return granularity;
    }
    return null;
  }
}
