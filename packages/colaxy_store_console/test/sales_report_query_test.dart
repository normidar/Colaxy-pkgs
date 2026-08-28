import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:test/test.dart';

void main() {
  group('filters', () {
    test('builds the parameters Apple documents', () {
      final query = SalesReportQuery.sales(date: DateTime.utc(2026, 8, 20));

      expect(query.toFilters(vendorNumber: '85000000'), {
        'filter[frequency]': 'DAILY',
        'filter[reportType]': 'SALES',
        'filter[reportSubType]': 'SUMMARY',
        'filter[vendorNumber]': '85000000',
        'filter[version]': '1_0',
        'filter[reportDate]': '2026-08-20',
      });
    });

    test('omits reportDate for a daily query with no date', () {
      // Daily is the one frequency where Apple defaults to the latest report.
      final filters = SalesReportQuery.sales().toFilters(vendorNumber: '1');

      expect(filters['filter[reportDate]'], isNull);
    });

    test('defaults to the newest version Apple documents', () {
      expect(SalesReportQuery.subscriptions().resolvedVersion, '1_3');
      expect(SalesReportQuery.subscribers().resolvedVersion, '1_3');
      expect(SalesReportQuery.sales().resolvedVersion, '1_0');
    });

    test('passes an explicit version through unvalidated', () {
      // Apple's published version list and the versions its API accepts have
      // drifted apart before, so an override must not be second-guessed.
      final query = SalesReportQuery.sales(version: '1_1');

      expect(query.resolvedVersion, '1_1');
      expect(
        query.toFilters(vendorNumber: '1')['filter[version]'],
        '1_1',
      );
    });
  });

  group('date format per frequency', () {
    test('daily and weekly send YYYY-MM-DD', () {
      expect(
        SalesReportQuery.sales(
          date: DateTime.utc(2026, 8, 20),
        ).toFilters(vendorNumber: '1')['filter[reportDate]'],
        '2026-08-20',
      );
      expect(
        SalesReportQuery.sales(
          frequency: SalesFrequency.weekly,
          date: DateTime.utc(2026, 8, 23),
        ).toFilters(vendorNumber: '1')['filter[reportDate]'],
        '2026-08-23',
      );
    });

    test('monthly sends YYYY-MM and yearly sends YYYY', () {
      // Sending a full date here is rejected, and Apple's error blames the
      // combination rather than the format.
      expect(
        SalesReportQuery.sales(
          frequency: SalesFrequency.monthly,
          date: DateTime.utc(2026, 8, 20),
        ).toFilters(vendorNumber: '1')['filter[reportDate]'],
        '2026-08',
      );
      expect(
        SalesReportQuery.sales(
          frequency: SalesFrequency.yearly,
          date: DateTime.utc(2026, 8, 20),
        ).toFilters(vendorNumber: '1')['filter[reportDate]'],
        '2026',
      );
    });

    test('pads single-digit months and days', () {
      expect(
        SalesFrequency.daily.formatDate(DateTime.utc(2026, 1, 5)),
        '2026-01-05',
      );
      expect(
        SalesFrequency.monthly.formatDate(DateTime.utc(2026, 1, 5)),
        '2026-01',
      );
    });
  });

  group('weekly boundary', () {
    test('rejects a date that does not close the week', () {
      // 2026-08-20 is a Thursday. Apple's weeks end on Sunday.
      expect(
        () => SalesReportQuery.sales(
          frequency: SalesFrequency.weekly,
          date: DateTime.utc(2026, 8, 20),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('endOfWeek'),
          ),
        ),
      );
    });

    test('endOfWeek moves a mid-week date to its Sunday', () {
      expect(
        SalesFrequency.endOfWeek(DateTime.utc(2026, 8, 20)),
        DateTime.utc(2026, 8, 23),
      );
      expect(
        SalesFrequency.endOfWeek(DateTime.utc(2026, 8, 17)),
        DateTime.utc(2026, 8, 23),
      );
    });

    test('endOfWeek leaves a Sunday alone', () {
      final sunday = DateTime.utc(2026, 8, 23);

      expect(SalesFrequency.endOfWeek(sunday), sunday);
      expect(SalesFrequency.isEndOfWeek(sunday), isTrue);
    });

    test('endOfWeek output is always accepted', () {
      expect(
        () => SalesReportQuery.sales(
          frequency: SalesFrequency.weekly,
          date: SalesFrequency.endOfWeek(DateTime.utc(2026, 8, 20)),
        ),
        returnsNormally,
      );
    });
  });

  group('combination validation', () {
    test('rejects a frequency Apple does not offer, naming the valid ones', () {
      // Apple answers this with INVALID_COMBINATION and a detail blaming the
      // date, which sends people debugging the wrong parameter.
      expect(
        () => SalesReportQuery(
          type: SalesReportType.subscriptionEvent,
          subType: SalesReportSubType.summary,
          frequency: SalesFrequency.monthly,
        ),
        throwsA(
          isA<ArgumentError>()
              .having(
                (e) => e.message,
                'names the parameter',
                contains('DAILY'),
              )
              .having(
                (e) => e.message,
                'names the report',
                contains('SUBSCRIPTION_EVENT'),
              ),
        ),
      );
    });

    test('rejects a sub-type Apple does not offer for the type', () {
      expect(
        () => SalesReportQuery(
          type: SalesReportType.subscriber,
          subType: SalesReportSubType.summaryChannel,
          frequency: SalesFrequency.daily,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('DETAILED'),
          ),
        ),
      );
    });

    test('requires a date for every frequency except daily', () {
      for (final frequency in [
        SalesFrequency.weekly,
        SalesFrequency.monthly,
        SalesFrequency.yearly,
      ]) {
        expect(
          () => SalesReportQuery.sales(frequency: frequency),
          throwsArgumentError,
          reason: '${frequency.wireName} needs a date',
        );
      }
      expect(SalesReportQuery.sales, returnsNormally);
    });

    test('resolves the version Apple lists for that exact frequency', () {
      // INSTALLS/DETAILED appears on two rows of Apple's table with
      // different versions. Merging them would default a yearly request to
      // 1_2, which only monthly accepts — a 400 for a report that exists.
      expect(
        SalesReportQuery(
          type: SalesReportType.installs,
          subType: SalesReportSubType.detailed,
          frequency: SalesFrequency.monthly,
          date: DateTime.utc(2026, 8, 20),
        ).resolvedVersion,
        '1_2',
      );
      expect(
        SalesReportQuery(
          type: SalesReportType.installs,
          subType: SalesReportSubType.detailed,
          frequency: SalesFrequency.yearly,
          date: DateTime.utc(2026, 8, 20),
        ).resolvedVersion,
        '1_1',
      );
    });

    test('lists every frequency of a report that spans several rows', () {
      expect(
        SalesReportCombination.frequenciesFor(
          SalesReportType.installs,
          SalesReportSubType.detailed,
        ),
        {SalesFrequency.monthly, SalesFrequency.yearly},
      );
      expect(
        () => SalesReportQuery(
          type: SalesReportType.installs,
          subType: SalesReportSubType.detailed,
          frequency: SalesFrequency.daily,
        ),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.message, 'lists monthly', contains('MONTHLY'))
              .having((e) => e.message, 'lists yearly', contains('YEARLY')),
        ),
      );
    });

    test('accepts every combination in Apple table', () {
      // Guards the transcription: a typo here would reject a report that
      // actually exists.
      for (final combination in SalesReportCombination.all) {
        for (final frequency in combination.frequencies) {
          expect(
            () => SalesReportQuery(
              type: combination.type,
              subType: combination.subType,
              frequency: frequency,
              date: frequency == SalesFrequency.weekly
                  ? DateTime.utc(2026, 8, 23)
                  : DateTime.utc(2026, 8, 20),
            ),
            returnsNormally,
            reason: '$combination at ${frequency.wireName}',
          );
          // And resolves to a version that row actually lists.
          expect(
            combination.versions,
            contains(
              SalesReportQuery(
                type: combination.type,
                subType: combination.subType,
                frequency: frequency,
                date: frequency == SalesFrequency.weekly
                    ? DateTime.utc(2026, 8, 23)
                    : DateTime.utc(2026, 8, 20),
              ).resolvedVersion,
            ),
            reason: '$combination at ${frequency.wireName}',
          );
        }
      }
    });
  });

  group('named constructors', () {
    test('match the combinations Apple offers', () {
      expect(SalesReportQuery.sales().type, SalesReportType.sales);
      expect(
        SalesReportQuery.subscriptions().subType,
        SalesReportSubType.summary,
      );
      expect(
        SalesReportQuery.subscribers().subType,
        SalesReportSubType.detailed,
      );
      expect(
        SalesReportQuery.subscriptionEvents().frequency,
        SalesFrequency.daily,
      );
    });
  });
}
