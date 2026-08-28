/// One measurement: a date, a value, and whatever it was broken down by.
///
/// ## Parameters
///
/// ### Required
/// - **[date]**: The day the measurement covers, as UTC midnight.
/// - **[value]**: The measurement.
///
/// ### Optional
/// - **[dimensions]**: What this point was broken down by, e.g.
///   `{'countryCode': 'JP'}` (default: empty, meaning the total).
///
/// ## Example
///
/// ```dart
/// final japanOnly = metric.whereDimension('countryCode', 'JP');
/// ```
class MetricPoint {
  /// Creates a measurement.
  const MetricPoint({
    required this.date,
    required this.value,
    this.dimensions = const {},
  });

  /// The day the measurement covers, as UTC midnight.
  ///
  /// Stores report calendar days, not instants. Keeping them at UTC midnight
  /// means the same report parses to the same day wherever the job runs.
  final DateTime date;

  /// The measurement.
  ///
  /// An `int` for counts, a `double` for rates and money. Read the owning
  /// metric's `unit` to know which.
  final num value;

  /// What this point was broken down by.
  ///
  /// Empty means it is the total for [date]. A metric holding both totals and
  /// per-country points would double-count if summed, so a metric carries one
  /// or the other, never both.
  final Map<String, String> dimensions;

  /// Whether this point carries no breakdown, i.e. it is a total.
  bool get isTotal => dimensions.isEmpty;

  @override
  String toString() {
    final suffix = dimensions.isEmpty ? '' : ' $dimensions';
    return 'MetricPoint(${date.toIso8601String().split('T').first}: '
        '$value$suffix)';
  }
}
