// Registers an ongoing analytics request, then collects whatever Apple has
// generated so far.
//
// Run it twice, a day or two apart: the first run registers, the second
// collects. That gap is Apple's, not this example's — the first data lands
// 24–48 hours after registration.
//
//   ASC_KEY_ID=ABCD123456 \
//   ASC_ISSUER_ID=69a6de70-0000-0000-0000-1f2c3d4e5f60 \
//   ASC_P8="$(cat AuthKey_ABCD123456.p8)" \
//   ASC_APP_ID=6740000000 \
//   dart run example/app_store_analytics_example.dart
import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';

Future<void> main() async {
  final env = Platform.environment;

  final console = AppStoreConnectConsole(
    apiKey: AppStoreApiKey(
      keyId: env['ASC_KEY_ID']!,
      issuerId: env['ASC_ISSUER_ID']!,
      privateKey: env['ASC_P8']!,
    ),
    appId: env['ASC_APP_ID']!,
    onLog: (message) => stderr.writeln('[asc] $message'),
  );

  final api = console.analytics;

  try {
    // Reuses a live request; registers a new one only if there is none, or if
    // Apple stopped the existing ones for inactivity — which also kills every
    // report ID underneath them.
    final request = await api.ensureRequest(AnalyticsAccessType.ongoing);
    stdout.writeln('Using request ${request.id}');

    final reports = await api.reports(
      request.id,
      // Filter by category, not name: report names are prose and Apple has
      // renamed them.
      category: AnalyticsReportCategory.appStoreEngagement,
    );

    if (reports.isEmpty) {
      stdout.writeln(
        'No reports yet. Apple takes 24-48 hours after a request is '
        'registered; run this again tomorrow.',
      );
      return;
    }

    for (final report in reports) {
      final instances = await api.instances(
        report.id,
        granularity: AnalyticsGranularity.daily,
      );
      stdout.writeln('\n${report.name} — ${instances.length} instances');

      for (final instance in instances.take(3)) {
        // downloadInstance lists the segments and joins them. The URLs are
        // pre-signed and expire, so they are fetched right after listing.
        final table = await api.downloadInstance(instance.id);
        final date = instance.processingDate
            ?.toIso8601String()
            .split('T')
            .first;
        stdout.writeln(
          '  $date: ${table.length} rows, '
          '${table.columns.length} columns',
        );
        if (table.isNotEmpty) {
          stdout.writeln('    columns: ${table.columns.take(6).join(', ')}…');
        }
      }
    }
  } finally {
    console.close();
  }
}
