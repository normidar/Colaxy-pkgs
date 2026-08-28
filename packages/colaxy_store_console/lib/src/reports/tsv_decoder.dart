import 'dart:convert';
import 'dart:io';

/// Reads the tab-separated reports App Store Connect serves.
///
/// Apple sends both its sales reports and its analytics report segments as
/// gzipped TSV — with no `Content-Encoding` header, so nothing unzips them
/// for you.
///
/// TSV here means what Apple means by it: cells are split on tabs and nothing
/// else. There is no quoting to interpret, so a cell containing a quote
/// character keeps it. That is not an oversight — treating `"` as a quote
/// would corrupt app titles that legitimately contain one.
abstract final class TsvDecoder {
  /// Splits [source] into rows of cells.
  ///
  /// Blank lines are dropped. Apple's reports end with a trailing newline,
  /// and some carry a blank line before a trailer, either of which would
  /// otherwise become an empty row that every caller has to filter.
  static List<List<String>> decode(String source) {
    final rows = <List<String>>[];
    for (final line in const LineSplitter().convert(source)) {
      if (line.trim().isEmpty) continue;
      rows.add(line.split('\t'));
    }
    return rows;
  }

  /// Decompresses [bytes] if needed, then splits them into rows.
  ///
  /// Whether the payload is gzipped is decided by its magic number rather
  /// than by a header, because Apple does not send one and has served the
  /// same endpoint both ways.
  static List<List<String>> decodeBytes(List<int> bytes) =>
      decode(decodeText(bytes));

  /// Decompresses [bytes] if needed and decodes them as UTF-8 text.
  static String decodeText(List<int> bytes) {
    final data = isGzipped(bytes) ? gzip.decode(bytes) : bytes;
    // `allowMalformed` keeps one bad byte in a reviewer's nickname from
    // failing an entire month of rows.
    return utf8.decode(data, allowMalformed: true);
  }

  /// Whether [bytes] starts with the gzip magic number.
  static bool isGzipped(List<int> bytes) =>
      bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
}
