/// One row of a `ReportTable`, read by column name.
///
/// Cells are kept as the store sent them and converted on demand. That is
/// deliberate: store reports carry money, and a report where every numeric
/// column had already been forced through a `double` would have lost the
/// exact figures before the caller ever saw them. Reach for `operator []`
/// when the string matters.
///
/// A conversion that cannot be made returns `null` rather than throwing. A
/// single unparseable cell in a year of daily rows should not take down the
/// whole import.
///
/// ## Parameters
///
/// ### Required
/// - **[columns]**: Header names as the store wrote them, shared with the
///   table this row came from.
/// - **[columnIndex]**: Normalised column name to position, likewise shared.
/// - **[cells]**: The row's raw cells.
///
/// ## Example
///
/// ```dart
/// for (final row in table.entries) {
///   print('${row.dateAt('Begin Date')}: ${row.intAt('Units')} units');
/// }
/// ```
class ReportRow {
  /// Creates a row. Normally obtained from a `ReportTable`, not built by hand.
  const ReportRow({
    required this.columns,
    required this.columnIndex,
    required this.cells,
  });

  /// Header names as the store wrote them.
  final List<String> columns;

  /// Normalised column name to position.
  final Map<String, int> columnIndex;

  /// The row's raw cells, in column order.
  final List<String> cells;

  /// Normalises a column name for lookup.
  ///
  /// Both stores have changed the casing and spacing of report headers
  /// between versions without announcing it, so lookups ignore both.
  static String normalise(String column) =>
      column.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// The raw cell under [column], or `null` if the column is absent or the
  /// cell is empty.
  ///
  /// Absent and empty are deliberately the same answer: a store that omits a
  /// column in one report version and sends it blank in the next should not
  /// make callers handle two cases.
  String? operator [](String column) {
    final index = columnIndex[normalise(column)];
    if (index == null || index >= cells.length) return null;
    final value = cells[index].trim();
    return value.isEmpty ? null : value;
  }

  /// The raw cell at [index], or `null` if the row is shorter than that.
  String? at(int index) {
    if (index < 0 || index >= cells.length) return null;
    final value = cells[index].trim();
    return value.isEmpty ? null : value;
  }

  /// [column] as an integer, or `null` if it is absent or not a number.
  ///
  /// Thousands separators are stripped, since Play's CSVs use them in some
  /// columns and not others.
  int? intAt(String column) {
    final value = this[column];
    if (value == null) return null;
    return int.tryParse(_stripSeparators(value)) ??
        double.tryParse(_stripSeparators(value))?.round();
  }

  /// [column] as a floating-point number, or `null` if it is absent or not a
  /// number.
  ///
  /// Money loses precision here. For amounts you intend to sum or compare,
  /// read the raw string with `operator []` and use a decimal type.
  double? decimalAt(String column) {
    final value = this[column];
    if (value == null) return null;
    return double.tryParse(_stripSeparators(value));
  }

  /// [column] as a UTC date, or `null` if it is absent or unrecognised.
  ///
  /// Report dates are calendar dates, not instants, so they come back as UTC
  /// midnight — otherwise the same report would parse to a different day
  /// depending on where the job ran.
  ///
  /// Recognised: `YYYY-MM-DD` (Google, and Apple's analytics reports),
  /// `MM/DD/YYYY` (Apple's sales reports), and full ISO 8601 timestamps.
  DateTime? dateAt(String column) {
    final value = this[column];
    return value == null ? null : parseDate(value);
  }

  /// Parses a report date in any of the formats the two stores use.
  static DateTime? parseDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.contains('T')) return DateTime.tryParse(trimmed)?.toUtc();

    final iso = _isoDate.firstMatch(trimmed);
    if (iso != null) {
      return DateTime.utc(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    // Apple's sales reports are MM/DD/YYYY. Reading them as DD/MM/YYYY would
    // silently succeed for the first twelve days of every month.
    final us = _usDate.firstMatch(trimmed);
    if (us != null) {
      return DateTime.utc(
        int.parse(us.group(3)!),
        int.parse(us.group(1)!),
        int.parse(us.group(2)!),
      );
    }

    return null;
  }

  /// This row as a map from column name to raw cell.
  ///
  /// Keys are the header names as the store wrote them, not the normalised
  /// forms used for lookup — a map keyed on `daily device installs` would be
  /// wrong to write back out, and surprising to read.
  ///
  /// Columns the row has no cell for, and empty cells, are left out.
  Map<String, String> toMap() {
    final map = <String, String>{};
    for (var i = 0; i < columns.length; i++) {
      final value = at(i);
      if (value != null) map[columns[i]] = value;
    }
    return map;
  }

  static final _isoDate = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
  static final _usDate = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');

  static String _stripSeparators(String value) => value.replaceAll(',', '');

  @override
  String toString() => 'ReportRow(${cells.join(' | ')})';
}
