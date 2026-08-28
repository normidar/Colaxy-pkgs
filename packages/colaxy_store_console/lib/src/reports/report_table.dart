import 'package:colaxy_store_console/src/reports/csv_decoder.dart';
import 'package:colaxy_store_console/src/reports/report_row.dart';
import 'package:colaxy_store_console/src/reports/tsv_decoder.dart';

/// A store report as a header row plus data rows.
///
/// Both stores hand their statistics over as tables, not as objects, and the
/// columns differ per report type — Apple's `SALES` and `SUBSCRIBER` reports
/// share almost none. Modelling each variant as a Dart class would mean
/// chasing two vendors' schema changes forever, so this package hands you the
/// table and documents the columns instead.
///
/// Lookups by column name ignore case and collapse whitespace, because both
/// stores have changed header casing between report versions.
///
/// ## Parameters
///
/// ### Required
/// - **[columns]**: Header names, in order.
/// - **[rows]**: Data rows, each a list of raw cells.
///
/// ## Example
///
/// ```dart
/// final table = ReportTable.fromGzippedTsv(bytes);
/// final units = table.entries
///     .map((row) => row.intAt('Units') ?? 0)
///     .fold(0, (a, b) => a + b);
/// ```
class ReportTable {
  /// Creates a table from an explicit header and rows.
  ReportTable({required this.columns, required this.rows});

  /// A table with no columns and no rows.
  ///
  /// This is what a store returns for a period it has no data for, which is
  /// an ordinary answer rather than a failure.
  ReportTable.empty() : columns = const [], rows = const [];

  /// Creates a table from decoded rows, taking the first as the header.
  ///
  /// An empty input yields [ReportTable.empty].
  factory ReportTable.fromRows(List<List<String>> rows) {
    if (rows.isEmpty) return ReportTable.empty();
    return ReportTable(
      columns: rows.first.map((column) => column.trim()).toList(),
      rows: rows.skip(1).toList(),
    );
  }

  /// Parses tab-separated text, as App Store Connect reports arrive.
  factory ReportTable.fromTsv(String source) =>
      ReportTable.fromRows(TsvDecoder.decode(source));

  /// Decompresses and parses a gzipped TSV payload.
  ///
  /// This is the normal path for App Store Connect: both sales reports and
  /// analytics segments arrive gzipped with no `Content-Encoding` header.
  factory ReportTable.fromGzippedTsv(List<int> bytes) =>
      ReportTable.fromRows(TsvDecoder.decodeBytes(bytes));

  /// Parses a CSV payload, as Google Play's Cloud Storage reports arrive.
  ///
  /// Takes bytes rather than a string because those files are UTF-16LE, and
  /// the encoding has to be read off the byte-order mark.
  factory ReportTable.fromCsvBytes(List<int> bytes) =>
      ReportTable.fromRows(CsvDecoder.decodeBytes(bytes));

  /// Joins tables that share a header into one.
  ///
  /// Apple splits a large analytics report instance across several segments,
  /// each an independent file carrying its own header row; only the
  /// concatenation is the report.
  ///
  /// Empty tables are skipped, so a period with no data does not blank the
  /// result. Throws [StateError] if two tables disagree on their columns:
  /// appending rows under the wrong header would silently shift every value
  /// one column over, which is worse than failing.
  factory ReportTable.concat(Iterable<ReportTable> tables) {
    ReportTable? first;
    final rows = <List<String>>[];

    for (final table in tables) {
      if (table.columns.isEmpty) continue;
      if (first == null) {
        first = table;
      } else if (!_sameColumns(first.columns, table.columns)) {
        throw StateError(
          'Cannot concatenate report tables with different columns: '
          '${first.columns.join(', ')} vs ${table.columns.join(', ')}',
        );
      }
      rows.addAll(table.rows);
    }

    if (first == null) return ReportTable.empty();
    return ReportTable(columns: first.columns, rows: rows);
  }

  /// Header names, in order.
  final List<String> columns;

  /// Data rows, each a list of raw cells.
  ///
  /// Rows are not padded to the header's width. A store that stops sending a
  /// trailing column produces short rows, which read as `null` cells rather
  /// than as an error.
  final List<List<String>> rows;

  /// Normalised column name to position.
  ///
  /// The first occurrence wins. Apple's detailed reports do repeat a header
  /// name in some versions, and the leftmost is the one the rest of the
  /// report is keyed on.
  late final Map<String, int> columnIndex = {
    for (var i = columns.length - 1; i >= 0; i--)
      ReportRow.normalise(columns[i]): i,
  };

  /// How many data rows there are, not counting the header.
  int get length => rows.length;

  /// Whether the table has no data rows.
  bool get isEmpty => rows.isEmpty;

  /// Whether the table has at least one data row.
  bool get isNotEmpty => rows.isNotEmpty;

  /// The row at [index].
  ReportRow operator [](int index) =>
      ReportRow(columnIndex: columnIndex, cells: rows[index]);

  /// Every data row, lazily.
  Iterable<ReportRow> get entries sync* {
    for (final cells in rows) {
      yield ReportRow(columnIndex: columnIndex, cells: cells);
    }
  }

  /// Whether [column] exists, ignoring case and whitespace.
  ///
  /// Worth checking before reading an optional column: both stores add and
  /// remove them between report versions.
  bool hasColumn(String column) =>
      columnIndex.containsKey(ReportRow.normalise(column));

  /// The position of [column], or `null` if there is no such column.
  int? indexOf(String column) => columnIndex[ReportRow.normalise(column)];

  static bool _sameColumns(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (ReportRow.normalise(a[i]) != ReportRow.normalise(b[i])) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'ReportTable(${columns.length} columns, ${rows.length} rows)';
}
