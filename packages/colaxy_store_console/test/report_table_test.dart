import 'dart:convert';
import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:test/test.dart';

const _salesReport =
    'Provider\tSKU\tTitle\tUnits\tDeveloper Proceeds\tBegin Date\t'
    'Country Code\n'
    'APPLE\tcom.example.app\tExample\t12\t0.70\t08/20/2026\tJP\n'
    'APPLE\tcom.example.app\tExample\t3\t1.40\t08/21/2026\tUS\n';

ReportTable get _table => ReportTable.fromTsv(_salesReport);

void main() {
  group('shape', () {
    test('takes the first row as the header', () {
      expect(_table.columns.first, 'Provider');
      expect(_table.columns, hasLength(7));
      expect(_table.length, 2);
      expect(_table.isNotEmpty, isTrue);
    });

    test('an empty payload yields an empty table, not a failure', () {
      // A store with no data for a period is an ordinary answer.
      final empty = ReportTable.fromTsv('');

      expect(empty.isEmpty, isTrue);
      expect(empty.columns, isEmpty);
      expect(empty.entries, isEmpty);
    });

    test('a header with no data rows is still a valid table', () {
      final headerOnly = ReportTable.fromTsv('Provider\tUnits\n');

      expect(headerOnly.columns, ['Provider', 'Units']);
      expect(headerOnly.isEmpty, isTrue);
    });
  });

  group('column lookup', () {
    test('finds a column ignoring case and extra whitespace', () {
      // Both stores have changed header casing between report versions.
      final row = _table[0];

      expect(row['Units'], '12');
      expect(row['units'], '12');
      expect(row['  UNITS  '], '12');
      expect(row['Developer  Proceeds'], '0.70');
    });

    test('hasColumn and indexOf agree with the header', () {
      expect(_table.hasColumn('Country Code'), isTrue);
      expect(_table.hasColumn('Subscriber Id'), isFalse);
      expect(_table.indexOf('sku'), 1);
      expect(_table.indexOf('nope'), isNull);
    });

    test('the leftmost column wins when a name repeats', () {
      // Apple's detailed reports do repeat a header name in some versions.
      final table = ReportTable.fromTsv('Units\tUnits\n1\t2\n');

      expect(table.indexOf('Units'), 0);
      expect(table[0]['Units'], '1');
    });
  });

  group('cell access', () {
    test('reads a missing column and an empty cell the same way', () {
      // A store that omits a column in one version and blanks it in the next
      // should not make callers handle two cases.
      final table = ReportTable.fromTsv('a\tb\n1\t\n');

      expect(table[0]['b'], isNull);
      expect(table[0]['nope'], isNull);
    });

    test('a row shorter than the header reads as null, not a crash', () {
      final table = ReportTable.fromTsv('a\tb\tc\n1\n');

      expect(table[0]['a'], '1');
      expect(table[0]['c'], isNull);
    });

    test('at() reads by position', () {
      expect(_table[0].at(0), 'APPLE');
      expect(_table[0].at(99), isNull);
      expect(_table[0].at(-1), isNull);
    });

    test('toMap omits absent and empty cells', () {
      final table = ReportTable.fromTsv('a\tb\tc\n1\t\t3\n');

      expect(table[0].toMap(), {'a': '1', 'c': '3'});
    });

    test('toMap keys on the header the store wrote, not the lookup form', () {
      // Lookups normalise case and spacing, but a map keyed on
      // `daily device installs` would be wrong to write back out and
      // surprising to read.
      final table = ReportTable.fromTsv(
        'Daily Device Installs\tCountry Code\n142\tJP\n',
      );

      expect(table[0].toMap(), {
        'Daily Device Installs': '142',
        'Country Code': 'JP',
      });
    });
  });

  group('conversions', () {
    test('intAt reads a count', () {
      expect(_table[0].intAt('Units'), 12);
      expect(_table[1].intAt('Units'), 3);
    });

    test('intAt strips the thousands separators Play uses', () {
      final table = ReportTable.fromTsv('Installs\n1,234\n');

      expect(table[0].intAt('Installs'), 1234);
    });

    test('intAt rounds a value that arrived as a decimal', () {
      final table = ReportTable.fromTsv('Units\n12.6\n');

      expect(table[0].intAt('Units'), 13);
    });

    test('decimalAt reads proceeds', () {
      expect(_table[0].decimalAt('Developer Proceeds'), 0.70);
    });

    test('a conversion that cannot be made returns null, not an exception', () {
      // One bad cell in a year of daily rows must not fail the import.
      final table = ReportTable.fromTsv('Units\tDate\nn/a\tsomeday\n');

      expect(table[0].intAt('Units'), isNull);
      expect(table[0].decimalAt('Units'), isNull);
      expect(table[0].dateAt('Date'), isNull);
      expect(table[0].intAt('nope'), isNull);
    });
  });

  group('dates', () {
    test("reads Apple's MM/DD/YYYY as month first", () {
      // Read as DD/MM/YYYY this would silently succeed for the first twelve
      // days of every month and be wrong for the rest.
      expect(_table[0].dateAt('Begin Date'), DateTime.utc(2026, 8, 20));
      expect(_table[1].dateAt('Begin Date'), DateTime.utc(2026, 8, 21));
    });

    test("reads Google's YYYY-MM-DD", () {
      final table = ReportTable.fromTsv('Date\n2026-08-20\n');

      expect(table[0].dateAt('Date'), DateTime.utc(2026, 8, 20));
    });

    test('reads a full ISO timestamp and normalises it to UTC', () {
      final table = ReportTable.fromTsv('Date\n2026-08-20T04:15:22-07:00\n');

      expect(table[0].dateAt('Date'), DateTime.utc(2026, 8, 20, 11, 15, 22));
    });

    test('returns UTC midnight so the day does not depend on the runner', () {
      final date = ReportTable.fromTsv('Date\n2026-08-20\n')[0].dateAt('Date');

      expect(date!.isUtc, isTrue);
      expect(date.hour, 0);
    });
  });

  group('factories', () {
    test('fromGzippedTsv decompresses an Apple payload', () {
      final table = ReportTable.fromGzippedTsv(
        gzip.encode(utf8.encode(_salesReport)),
      );

      expect(table.length, 2);
      expect(table[0]['Country Code'], 'JP');
    });

    test('fromCsvBytes reads a UTF-16LE Play payload', () {
      const source = 'Date,Daily Device Installs\n2026-08-20,142\n';
      final bytes = <int>[0xFF, 0xFE];
      for (final unit in source.codeUnits) {
        bytes
          ..add(unit & 0xFF)
          ..add((unit >> 8) & 0xFF);
      }

      final table = ReportTable.fromCsvBytes(bytes);

      expect(table[0].intAt('Daily Device Installs'), 142);
      expect(table[0].dateAt('Date'), DateTime.utc(2026, 8, 20));
    });
  });

  test('entries walks every data row', () {
    expect(_table.entries.map((row) => row['Country Code']), ['JP', 'US']);
  });
}
