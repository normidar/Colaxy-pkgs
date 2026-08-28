/// How often a sales report is cut.
///
/// The frequency also decides how `filter[reportDate]` must be written, which
/// is why formatting lives here rather than at the call site — Apple rejects a
/// monthly request carrying a `YYYY-MM-DD` date, and the error it returns
/// blames the combination rather than the format.
enum SalesFrequency {
  /// One day. Available the following day.
  daily('DAILY'),

  /// One week, ending on a Sunday. Available on Mondays.
  weekly('WEEKLY'),

  /// One calendar month. Available five days after the month ends.
  monthly('MONTHLY'),

  /// One calendar year. Available six days after the year ends.
  yearly('YEARLY');

  const SalesFrequency(this.wireName);

  /// The value Apple expects in `filter[frequency]`.
  final String wireName;

  /// Whether Apple requires a `filter[reportDate]` for this frequency.
  ///
  /// Daily is the exception: omitting the date returns the most recent day
  /// Apple has generated.
  bool get requiresDate => this != daily;

  /// Formats [date] the way `filter[reportDate]` expects for this frequency.
  ///
  /// Daily and weekly take `YYYY-MM-DD`, monthly `YYYY-MM`, yearly `YYYY`.
  String formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return switch (this) {
      daily || weekly => '$year-$month-$day',
      monthly => '$year-$month',
      yearly => year,
    };
  }

  /// The Sunday that closes the week containing [date].
  ///
  /// Apple's weeks end on Sunday and a weekly report is addressed by that
  /// closing date. Reports of what Apple does with any other day differ —
  /// sometimes a rejection, sometimes a silent snap to a week boundary — and
  /// the silent snap is the reason `SalesReportQuery` refuses the request
  /// outright rather than letting you receive a week you did not ask for.
  /// Run this first:
  ///
  /// ```dart
  /// final query = SalesReportQuery.sales(
  ///   frequency: SalesFrequency.weekly,
  ///   date: SalesFrequency.endOfWeek(DateTime.utc(2026, 8, 20)),
  /// );
  /// ```
  static DateTime endOfWeek(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    // DateTime.sunday is 7, so a Sunday needs no adjustment and a Monday
    // moves forward six days.
    return day.add(Duration(days: DateTime.sunday - day.weekday));
  }

  /// Whether [date] closes a week, i.e. falls on a Sunday.
  static bool isEndOfWeek(DateTime date) => date.weekday == DateTime.sunday;
}
