// Prints three weeks of Android crash rate, worst countries first.
//
//   PLAY_KEY_JSON="$(cat play-api.json)" \
//   dart run example/play_vitals_example.dart
import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';

const packageName = 'com.example.app';

Future<void> main() async {
  final account = PlayServiceAccount.fromJsonString(
    Platform.environment['PLAY_KEY_JSON']!,
  );

  // Vitals need their own scope. A token minted for the Android Publisher
  // scope is rejected here, and the rejection looks like a bad key.
  final api = PlayVitalsApi(
    client: PlayReportingClient(
      authenticatedClient: await account.authenticate(
        scopes: [PlayServiceAccount.reportingScope],
      ),
      onLog: (message) => stderr.writeln('[play] $message'),
    ),
    packageName: packageName,
  );

  try {
    // Recent buckets are still being filled in. Stopping where Google says
    // the data has settled keeps stored figures from disagreeing with Play
    // Console tomorrow.
    final freshness = await api.freshness(VitalsMetricSet.crashRate);
    final until = freshness.clamp(
      DateTime.now().toUtc(),
      AggregationPeriod.daily,
    );
    final from = until.subtract(const Duration(days: 21));

    final byCountry = await api.queryOne(
      VitalsQuery(
        metricSet: VitalsMetricSet.crashRate,
        metrics: const ['userPerceivedCrashRate'],
        from: from,
        to: until,
        dimensions: const ['countryCode'],
      ),
      'userPerceivedCrashRate',
    );

    if (byCountry.isEmpty) {
      stdout.writeln('No crash data between $from and $until.');
      return;
    }

    // A crash rate is a proportion, so these are averaged, never summed —
    // MetricUnit.rate records which is meaningful.
    final averages = <String, List<num>>{};
    for (final point in byCountry.points) {
      final country = point.dimensions['countryCode'] ?? 'unknown';
      (averages[country] ??= <num>[]).add(point.value);
    }

    final ranked =
        averages.entries
            .map(
              (entry) => (
                country: entry.key,
                rate: entry.value.reduce((a, b) => a + b) / entry.value.length,
              ),
            )
            .toList()
          ..sort((a, b) => b.rate.compareTo(a.rate));

    final period = byCountry.period!;
    stdout.writeln(
      'Crash rate ${period.from.toIso8601String().split('T').first} to '
      '${period.to.toIso8601String().split('T').first} '
      '(${AggregationPeriod.daily.timeZoneId} days):',
    );
    for (final entry in ranked.take(10)) {
      final percent = (entry.rate * 100).toStringAsFixed(2);
      stdout.writeln('  ${entry.country.padRight(8)} $percent%');
    }
  } finally {
    api.close();
  }
}
