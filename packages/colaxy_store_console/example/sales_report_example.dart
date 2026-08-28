// Prints a week of App Store units and proceeds, per SKU.
//
//   ASC_KEY_ID=ABCD123456 \
//   ASC_ISSUER_ID=69a6de70-0000-0000-0000-1f2c3d4e5f60 \
//   ASC_P8="$(cat AuthKey_ABCD123456.p8)" \
//   ASC_VENDOR_NUMBER=85000000 \
//   dart run example/sales_report_example.dart
import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';

Future<void> main() async {
  final env = Platform.environment;

  final team = AppStoreTeam(
    apiKey: AppStoreApiKey(
      keyId: env['ASC_KEY_ID']!,
      issuerId: env['ASC_ISSUER_ID']!,
      privateKey: env['ASC_P8']!,
    ),
    // Team-scoped, not app-scoped: one report covers every app in the
    // account. Find it under Payments and Financial Reports.
    vendorNumber: env['ASC_VENDOR_NUMBER']!,
    onLog: (message) => stderr.writeln('[asc] $message'),
  );

  // Yesterday back a week. Today's report does not exist yet — daily reports
  // land the following day.
  final today = DateTime.now().toUtc();
  final days = [
    for (var back = 1; back <= 7; back++)
      DateTime.utc(today.year, today.month, today.day - back),
  ];

  final unitsBySku = <String, int>{};
  var proceeds = 0.0;

  try {
    final queries = days.map((day) => SalesReportQuery.sales(date: day));

    await for (final table in team.salesReports.fetchAll(queries)) {
      // An empty table with no columns is a day with no sales — an ordinary
      // answer that arrives as a 404, not a failure.
      if (table.columns.isEmpty) continue;

      for (final row in table.entries) {
        final sku = row['SKU'] ?? 'unknown';
        unitsBySku[sku] = (unitsBySku[sku] ?? 0) + (row.intAt('Units') ?? 0);
        proceeds += row.decimalAt('Developer Proceeds') ?? 0;
      }
    }
  } finally {
    team.close();
  }

  final ranked = unitsBySku.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final entry in ranked) {
    stdout.writeln('${entry.key.padRight(32)} ${entry.value} units');
  }

  // Proceeds are per-row in the customer's currency, so this total only means
  // something if you sell in one. Convert per row otherwise.
  stdout.writeln('\nProceeds across all rows: ${proceeds.toStringAsFixed(2)}');
}
