import 'dart:convert';

/// Reads the CSV reports Google Play drops in the developer's Cloud Storage
/// bucket.
///
/// These are the install, rating, crash and revenue numbers that have no API
/// at all. Two things make them awkward, and both are handled here:
///
/// - **They are UTF-16LE with a byte-order mark.** Decoding them as UTF-8
///   yields a string with a NUL between every character, which then splits
///   into nonsense rather than failing outright.
/// - **They are genuinely quoted CSV.** App titles contain commas, so
///   splitting on `,` corrupts rows in exactly the reports people care about.
abstract final class CsvDecoder {
  /// Parses [source] into rows of cells, honouring RFC 4180 quoting.
  ///
  /// A quoted field may span newlines and may contain `""` for a literal
  /// quote. Blank lines are dropped.
  static List<List<String>> decode(String source) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var fieldWasQuoted = false;

    void endField() {
      row.add(field.toString());
      field.clear();
      fieldWasQuoted = false;
    }

    void endRow() {
      // Captured before endField clears it: `""` is a present-but-empty
      // value and must survive, while a blank padding line must not.
      final quoted = fieldWasQuoted;
      endField();
      if (row.length > 1 ||
          quoted ||
          (row.isNotEmpty && row.first.trim().isNotEmpty)) {
        rows.add(row);
      }
      row = <String>[];
    }

    for (var i = 0; i < source.length; i++) {
      final char = source[i];

      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < source.length && source[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(char);
        }
        continue;
      }

      switch (char) {
        case '"':
          inQuotes = true;
          fieldWasQuoted = true;
        case ',':
          endField();
        case '\n':
          endRow();
        case '\r':
          // Swallowed so CRLF files do not leave a stray \r on every last
          // cell. Inside quotes it is preserved by the branch above.
          break;
        default:
          field.write(char);
      }
    }

    if (field.isNotEmpty || row.isNotEmpty || fieldWasQuoted) endRow();
    return rows;
  }

  /// Decodes [bytes] as text and parses it.
  static List<List<String>> decodeBytes(List<int> bytes) =>
      decode(decodeText(bytes));

  /// Decodes [bytes] as text, picking the encoding from the byte-order mark.
  ///
  /// UTF-16LE (`FF FE`) is what Play uses today; UTF-8 with or without a BOM
  /// is accepted too, since Google has served both.
  static String decodeText(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        units.add(bytes[i] | (bytes[i + 1] << 8));
      }
      // fromCharCodes reads these as UTF-16 code units, so surrogate pairs —
      // emoji in an app title — survive.
      return String.fromCharCodes(units);
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
