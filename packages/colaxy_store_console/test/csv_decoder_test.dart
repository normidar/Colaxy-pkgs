import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:test/test.dart';

/// Encodes [text] the way Google Play writes its report CSVs: UTF-16LE with a
/// byte-order mark.
List<int> _utf16le(String text) {
  final bytes = <int>[0xFF, 0xFE];
  for (final unit in text.codeUnits) {
    bytes
      ..add(unit & 0xFF)
      ..add((unit >> 8) & 0xFF);
  }
  return bytes;
}

void main() {
  group('decode', () {
    test('parses a Play installs report', () {
      const source =
          'Date,Package Name,Daily Device Installs,Daily Device Uninstalls\n'
          '2026-08-20,com.example.app,142,17\n';

      final rows = CsvDecoder.decode(source);

      expect(rows, hasLength(2));
      expect(rows[1], ['2026-08-20', 'com.example.app', '142', '17']);
    });

    test('keeps a comma inside a quoted field', () {
      // App titles contain commas, so splitting on ',' corrupts exactly the
      // reports people look at.
      final rows = CsvDecoder.decode('Title,Units\n"Example, Inc.",12\n');

      expect(rows[1], ['Example, Inc.', '12']);
    });

    test('unescapes a doubled quote', () {
      final rows = CsvDecoder.decode('Title\n"The ""Best"" App"\n');

      expect(rows[1].single, 'The "Best" App');
    });

    test('keeps a newline inside a quoted field', () {
      final rows = CsvDecoder.decode('Review\n"line one\nline two"\n');

      expect(rows, hasLength(2));
      expect(rows[1].single, 'line one\nline two');
    });

    test('handles CRLF between records', () {
      final rows = CsvDecoder.decode('a,b\r\n1,2\r\n');

      expect(rows, [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('preserves an empty trailing field', () {
      final rows = CsvDecoder.decode('a,b,c\n1,,\n');

      expect(rows[1], ['1', '', '']);
    });

    test('reads a final row with no trailing newline', () {
      final rows = CsvDecoder.decode('a,b\n1,2');

      expect(rows, hasLength(2));
    });

    test('keeps an explicitly quoted empty row', () {
      // `""` is a present-but-empty value, unlike a blank padding line.
      expect(CsvDecoder.decode('a\n""'), hasLength(2));
    });

    test('returns nothing for empty input', () {
      expect(CsvDecoder.decode(''), isEmpty);
      expect(CsvDecoder.decode('\n\n'), isEmpty);
    });
  });

  group('decodeText', () {
    test('decodes UTF-16LE, which is what Play actually writes', () {
      // Read as UTF-8 this would come back with a NUL between every
      // character and then split into nonsense rather than failing.
      final text = CsvDecoder.decodeText(_utf16le('Date,Installs\n'));

      expect(text, 'Date,Installs\n');
    });

    test('keeps non-ASCII text intact through UTF-16LE', () {
      final text = CsvDecoder.decodeText(_utf16le('タイトル,設置数\n'));

      expect(text, 'タイトル,設置数\n');
    });

    test('keeps a surrogate pair intact', () {
      // An emoji in an app title is two UTF-16 code units.
      final text = CsvDecoder.decodeText(_utf16le('Example 🎉'));

      expect(text, 'Example 🎉');
    });

    test('strips a UTF-8 byte-order mark', () {
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('Date,Installs')];

      expect(CsvDecoder.decodeText(bytes), 'Date,Installs');
    });

    test('accepts plain UTF-8 with no mark', () {
      expect(CsvDecoder.decodeText(utf8.encode('Date,設置数')), 'Date,設置数');
    });
  });

  group('decodeBytes', () {
    test('decodes and parses a UTF-16LE report end to end', () {
      final bytes = _utf16le(
        'Date,Package Name,Daily Device Installs\n'
        '2026-08-20,com.example.app,142\n',
      );

      final rows = CsvDecoder.decodeBytes(bytes);

      expect(rows, hasLength(2));
      expect(rows[1].last, '142');
    });
  });
}
