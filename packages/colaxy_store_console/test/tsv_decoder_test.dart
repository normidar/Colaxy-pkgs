import 'dart:convert';
import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:test/test.dart';

/// The header and one row of an App Store Connect `SALES`/`SUMMARY` report,
/// with the column names Apple actually sends.
const _salesReport =
    'Provider\tProvider Country\tSKU\tDeveloper\tTitle\tVersion\t'
    'Product Type Identifier\tUnits\tDeveloper Proceeds\tBegin Date\t'
    'End Date\tCustomer Currency\tCountry Code\n'
    'APPLE\tUS\tcom.example.app\tExample Inc\tExample\t2.4.1\t'
    '1F\t12\t0.70\t08/20/2026\t08/20/2026\tJPY\tJP\n';

void main() {
  group('decode', () {
    test('splits a sales report into header and rows', () {
      final rows = TsvDecoder.decode(_salesReport);

      expect(rows, hasLength(2));
      expect(rows.first.first, 'Provider');
      expect(rows.first, hasLength(13));
      expect(rows[1][7], '12');
    });

    test('drops the trailing blank line Apple ends reports with', () {
      // Left in, it becomes an all-empty row that every caller must filter.
      expect(TsvDecoder.decode('a\tb\n1\t2\n\n'), hasLength(2));
    });

    test('handles CRLF line endings', () {
      final rows = TsvDecoder.decode('a\tb\r\n1\t2\r\n');

      expect(rows, [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('keeps quote characters as data', () {
      // TSV has no quoting. An app called `The "Best" App` must survive.
      final rows = TsvDecoder.decode('Title\n"The ""Best"" App"\n');

      expect(rows[1].single, '"The ""Best"" App"');
    });

    test('keeps empty cells so column positions stay aligned', () {
      final rows = TsvDecoder.decode('a\tb\tc\n1\t\t3\n');

      expect(rows[1], ['1', '', '3']);
    });

    test('returns nothing for empty or whitespace-only input', () {
      expect(TsvDecoder.decode(''), isEmpty);
      expect(TsvDecoder.decode('\n\n  \n'), isEmpty);
    });
  });

  group('decodeBytes', () {
    test('decompresses the gzip Apple sends without a header', () {
      // Apple serves gzip with no Content-Encoding, so nothing in the HTTP
      // stack unzips it first.
      final gzipped = gzip.encode(utf8.encode(_salesReport));

      final rows = TsvDecoder.decodeBytes(gzipped);

      expect(rows, hasLength(2));
      expect(rows[1][12], 'JP');
    });

    test('accepts plain TSV bytes too', () {
      // The same endpoint has been observed serving both.
      final rows = TsvDecoder.decodeBytes(utf8.encode(_salesReport));

      expect(rows, hasLength(2));
    });

    test('survives a malformed byte instead of failing the whole report', () {
      final rows = TsvDecoder.decodeBytes([
        ...utf8.encode('Title\nCaf'),
        0xFF,
        ...utf8.encode('\n'),
      ]);

      expect(rows, hasLength(2));
    });
  });

  group('isGzipped', () {
    test('recognises the gzip magic number', () {
      expect(TsvDecoder.isGzipped(gzip.encode(utf8.encode('x'))), isTrue);
    });

    test('rejects plain text and short input', () {
      expect(TsvDecoder.isGzipped(utf8.encode('Provider\t')), isFalse);
      expect(TsvDecoder.isGzipped([0x1f]), isFalse);
      expect(TsvDecoder.isGzipped([]), isFalse);
    });
  });
}
