/// How Android vitals buckets a metric over time.
///
/// The time zone is not a detail you can ignore. A `DAILY` bucket is a
/// **Los Angeles** calendar day, not a UTC one — Google says this is a
/// historical constraint and offers no way to change it. So a Play daily
/// figure and an App Store daily figure for "the same day" cover different
/// 24-hour windows, and neither lines up with a UTC day.
enum AggregationPeriod {
  /// Hourly buckets, in UTC.
  hourly('HOURLY', 'UTC'),

  /// Calendar-day buckets, in `America/Los_Angeles`.
  ///
  /// This is the only time zone Google supports for daily vitals.
  daily('DAILY', 'America/Los_Angeles'),

  /// One bucket covering the whole requested range.
  fullRange('FULL_RANGE', null);

  const AggregationPeriod(this.wireName, this.timeZoneId);

  /// The value Google expects in `timelineSpec.aggregationPeriod`.
  final String wireName;

  /// The zone the buckets are cut in, or `null` for [fullRange].
  ///
  /// Worth surfacing when you display a daily figure: labelling a Los Angeles
  /// day as a local one is off by up to a day at the edges.
  final String? timeZoneId;

  /// Whether rolling averages are available at this period.
  ///
  /// The `…7dUserWeighted` and `…28dUserWeighted` metrics are daily rolling
  /// averages and Google does not compute them hourly.
  bool get supportsRollingAverages => this != hourly;
}
