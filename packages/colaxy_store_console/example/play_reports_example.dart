// Prints Google Play installs per country for the most recent published
// month, plus the running rating average.
//
//   PLAY_KEY_JSON="$(cat play-api.json)" \
//   PLAY_BUCKET="gs://pubsite_prod_rev_01234567890123456789/stats/installs/" \
//   dart run example/play_reports_example.dart
import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';

const packageName = 'com.example.app';

Future<void> main() async {
  final env = Platform.environment;
  final account = PlayServiceAccount.fromJsonString(env['PLAY_KEY_JSON']!);

  final api = PlayReportsApi(
    client: PlayStorageClient(
      authenticatedClient: await account.authenticate(
        scopes: [PlayServiceAccount.storageReadScope],
      ),
      onLog: (message) => stderr.writeln('[gcs] $message'),
    ),
    // The whole "Copy Cloud Storage URI" string is accepted.
    bucket: env['PLAY_BUCKET']!,
    packageName: packageName,
  );

  try {
    // Google says not to depend on its publishing schedule, so ask which
    // months exist rather than assuming last month is there.
    final published = await api.list(PlayReportType.installs);
    final latest = published
        .where((n) => n.endsWith('_country.csv'))
        .lastOrNull;

    if (latest == null) {
      stderr.writeln('No installs reports in the bucket for $packageName.');
      return;
    }

    stdout.writeln('Installs by country — $latest');
    final installs = await api.fetchObject(latest);
    final byCountry = <String, int>{};
    for (final row in installs.entries) {
      final country = row['Country'] ?? 'unknown';
      byCountry[country] =
          (byCountry[country] ?? 0) + (row.intAt('Daily Device Installs') ?? 0);
    }

    final ranked = byCountry.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in ranked.take(10)) {
      stdout.writeln('  ${entry.key.padRight(8)} ${entry.value}');
    }

    // The ratings report is the only place a real average comes from: the
    // reviews API omits ratings that carry no text.
    final ratings = api.fetchAll(
      PlayReportType.ratings,
      dimension: 'overview',
    );

    var total = 0.0;
    var days = 0;
    await for (final table in ratings) {
      for (final row in table.entries) {
        final daily = row.decimalAt('Daily Average Rating');
        if (daily == null) continue;
        total += daily;
        days++;
      }
    }

    if (days > 0) {
      stdout.writeln(
        '\nAverage of daily ratings across $days days: '
        '${(total / days).toStringAsFixed(2)}',
      );
    }
  } finally {
    api.close();
  }
}
