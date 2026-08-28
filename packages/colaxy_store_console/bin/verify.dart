// Checks this package against the real stores.
//
// Every surface is independent: supply the credentials you have and the rest
// are skipped, so you can verify one store, or one API, at a time.
//
// Read-only by default. Nothing is posted, created or deleted unless you pass
// --allow-writes, which is documented per check below.
//
//   dart run colaxy_store_console:verify
//
// See `--help` for the environment variables each check needs.
// Results are appended one check at a time, each a multi-line await. A
// cascade over those reads worse than repeating the receiver.
// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';

/// What a single check concluded.
enum _Outcome { pass, fail, skip }

/// One check's result, with enough detail to act on a failure.
class _Result {
  _Result(this.name, this.outcome, this.detail);

  final String name;
  final _Outcome outcome;
  final String detail;
}

const _usage = '''
Verifies colaxy_store_console against the real App Store Connect and Google
Play APIs. Read-only unless --allow-writes is passed.

Usage: dart run colaxy_store_console:verify [--allow-writes]

Environment variables, per surface. Supply what you have; the rest is skipped.

  App Store reviews, analytics
    ASC_KEY_ID         10-character key ID
    ASC_ISSUER_ID      issuer UUID
    ASC_P8             contents of the .p8 file (not the path)
    ASC_APP_ID         numeric app ID from the App Store Connect URL

  App Store sales reports
    ASC_KEY_ID, ASC_ISSUER_ID, ASC_P8
    ASC_VENDOR_NUMBER  from Payments and Financial Reports

  Google Play reviews
    PLAY_KEY_JSON      contents of the service-account JSON
    PLAY_PACKAGE       application ID, e.g. com.example.app

  Google Play vitals
    PLAY_KEY_JSON, PLAY_PACKAGE

  Google Play report CSVs
    PLAY_KEY_JSON, PLAY_PACKAGE
    PLAY_BUCKET        the "Copy Cloud Storage URI" string, or the bucket id

Writes performed only with --allow-writes:
  - App Store analytics: registers an ONGOING report request if none exists.
    Apple has no way to preview this, and an unused request is stopped
    automatically, so it is the one write worth making. Nothing is deleted.

Exit code is non-zero if any check failed. Skipped checks do not fail the run.
''';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write(_usage);
    return;
  }
  final allowWrites = args.contains('--allow-writes');
  final env = Platform.environment;

  final results = <_Result>[
    ...await _appStoreChecks(env, allowWrites: allowWrites),
    ...await _playChecks(env),
  ];

  stdout.writeln();
  for (final result in results) {
    final tag = switch (result.outcome) {
      _Outcome.pass => 'PASS',
      _Outcome.fail => 'FAIL',
      _Outcome.skip => 'SKIP',
    };
    stdout.writeln('$tag  ${result.name.padRight(34)} ${result.detail}');
  }

  final failed = results.where((r) => r.outcome == _Outcome.fail).length;
  final passed = results.where((r) => r.outcome == _Outcome.pass).length;
  final skipped = results.where((r) => r.outcome == _Outcome.skip).length;
  stdout.writeln('\n$passed passed, $failed failed, $skipped skipped.');

  if (skipped > 0 && failed == 0) {
    stdout.writeln(
      'Skipped checks were not verified against the real API. Supply their '
      'credentials before trusting those surfaces.',
    );
  }
  if (failed > 0) exit(1);
}

/// Runs [check], turning any failure into a readable result.
///
/// A verification tool that dies on the first error tells you less than one
/// that reports every surface, so nothing is allowed to escape.
Future<_Result> _run(String name, Future<String> Function() check) async {
  // Progress goes to a terminal only. Piped or redirected, the carriage
  // returns would leave half-erased lines in the output.
  final live = stdout.hasTerminal;
  if (live) stdout.write('${'… $name'.padRight(60)}\r');
  try {
    return _Result(name, _Outcome.pass, await check());
  } on StoreConsoleException catch (error) {
    // These already carry a message naming the likely setup mistake.
    return _Result(name, _Outcome.fail, error.toString());
  } on Object catch (error) {
    return _Result(name, _Outcome.fail, '$error');
  } finally {
    if (live) stdout.write('${' ' * 60}\r');
  }
}

_Result _skip(String name, String missing) =>
    _Result(name, _Outcome.skip, 'needs $missing');

Future<List<_Result>> _appStoreChecks(
  Map<String, String> env, {
  required bool allowWrites,
}) async {
  final keyId = env['ASC_KEY_ID'];
  final issuerId = env['ASC_ISSUER_ID'];
  final p8 = env['ASC_P8'];
  final appId = env['ASC_APP_ID'];
  final vendorNumber = env['ASC_VENDOR_NUMBER'];

  if (keyId == null || issuerId == null || p8 == null) {
    return [
      _skip('App Store credentials', 'ASC_KEY_ID, ASC_ISSUER_ID, ASC_P8'),
      _skip('App Store reviews', 'ASC_* credentials'),
      _skip('App Store sales reports', 'ASC_* credentials'),
      _skip('App Store analytics', 'ASC_* credentials'),
    ];
  }

  final results = <_Result>[];
  late final AppStoreApiKey key;

  results.add(
    await _run('App Store credentials', () async {
      key = AppStoreApiKey(keyId: keyId, issuerId: issuerId, privateKey: p8);
      // Signing locally proves the .p8 parses; only a request proves Apple
      // accepts it, which the checks below do.
      final token = AppStoreTokenProvider(key).token();
      return 'signed a token for key $keyId (${token.length} chars)';
    }),
  );
  if (results.last.outcome == _Outcome.fail) {
    return [
      ...results,
      _skip('App Store reviews', 'a usable .p8'),
      _skip('App Store sales reports', 'a usable .p8'),
      _skip('App Store analytics', 'a usable .p8'),
    ];
  }

  if (appId == null) {
    results
      ..add(_skip('App Store reviews', 'ASC_APP_ID'))
      ..add(_skip('App Store analytics', 'ASC_APP_ID'));
  } else {
    final console = AppStoreConnectConsole(apiKey: key, appId: appId);
    try {
      results.add(
        await _run('App Store reviews', () async {
          final page = await console.reviews.listPage(
            const ReviewQuery(pageSize: 1),
          );
          final total = page.total;
          return 'read ${page.reviews.length} review'
              '${total == null ? '' : ' of $total'}';
        }),
      );
      results.add(
        await _run('App Store analytics', () async {
          final requests = await console.analytics.requests();
          if (requests.isEmpty && !allowWrites) {
            return 'no report request registered; rerun with --allow-writes '
                'to create one';
          }
          final request = allowWrites
              ? await console.analytics.ensureRequest(
                  AnalyticsAccessType.ongoing,
                )
              : requests.first;

          final reports = await console.analytics.reports(request.id);
          if (reports.isEmpty) {
            return 'request ${request.id} exists, no reports yet — Apple '
                'takes 24-48 hours';
          }
          // The chain past this point is what the mocked tests cannot prove.
          final instances = await console.analytics.instances(reports.first.id);
          if (instances.isEmpty) {
            return '${reports.length} reports, none generated yet';
          }
          final table = await console.analytics.downloadInstance(
            instances.first.id,
          );
          return '${reports.length} reports; downloaded '
              '${table.length} rows, ${table.columns.length} columns';
        }),
      );
    } finally {
      console.close();
    }
  }

  if (vendorNumber == null) {
    results.add(_skip('App Store sales reports', 'ASC_VENDOR_NUMBER'));
  } else {
    final team = AppStoreTeam(apiKey: key, vendorNumber: vendorNumber);
    try {
      results.add(
        await _run('App Store sales reports', () async {
          // Yesterday: today's daily report does not exist yet.
          final now = DateTime.now().toUtc();
          final day = DateTime.utc(now.year, now.month, now.day - 1);
          final table = await team.salesReports.fetch(
            SalesReportQuery.sales(date: day),
          );
          if (table.columns.isEmpty) {
            return 'no sales on ${_day(day)} — a real answer, not a failure';
          }
          return '${table.length} rows for ${_day(day)}; '
              'columns: ${table.columns.take(4).join(', ')}…';
        }),
      );

      // The defect review turned up a version-per-frequency mix-up here, and
      // only a real request can confirm the fix.
      results.add(
        await _run('App Store installs (yearly, v1_1)', () async {
          final table = await team.salesReports.fetch(
            SalesReportQuery(
              type: SalesReportType.installs,
              subType: SalesReportSubType.detailed,
              frequency: SalesFrequency.yearly,
              date: DateTime.utc(DateTime.now().year - 1),
            ),
          );
          return table.columns.isEmpty
              ? 'accepted the request; no data for last year'
              : '${table.length} rows, ${table.columns.length} columns';
        }),
      );
    } finally {
      team.close();
    }
  }

  return results;
}

Future<List<_Result>> _playChecks(Map<String, String> env) async {
  final keyJson = env['PLAY_KEY_JSON'];
  final packageName = env['PLAY_PACKAGE'];
  final bucket = env['PLAY_BUCKET'];

  if (keyJson == null || packageName == null) {
    return [
      _skip('Google Play credentials', 'PLAY_KEY_JSON, PLAY_PACKAGE'),
      _skip('Google Play reviews', 'PLAY_* credentials'),
      _skip('Google Play vitals', 'PLAY_* credentials'),
      _skip('Google Play report CSVs', 'PLAY_* credentials'),
    ];
  }

  final results = <_Result>[];
  late final PlayServiceAccount account;

  results.add(
    await _run('Google Play credentials', () async {
      account = PlayServiceAccount.fromJsonString(keyJson);
      return 'service account ${account.clientEmail}';
    }),
  );
  if (results.last.outcome == _Outcome.fail) {
    return [
      ...results,
      _skip('Google Play reviews', 'a usable key'),
      _skip('Google Play vitals', 'a usable key'),
      _skip('Google Play report CSVs', 'a usable key'),
    ];
  }

  results.add(
    await _run('Google Play reviews', () async {
      final console = await GooglePlayConsole.connect(
        account: account,
        packageName: packageName,
      );
      try {
        final page = await console.reviews.listPage(
          const ReviewQuery(pageSize: 1),
        );
        return page.reviews.isEmpty
            ? 'no reviews in the last seven days — the API reaches no further'
            : 'read ${page.reviews.length} review';
      } finally {
        console.close();
      }
    }),
  );

  results.add(
    await _run('Google Play vitals', () async {
      // A different scope from reviews: this is the check that catches a
      // token minted for the wrong one.
      final client = PlayReportingClient(
        authenticatedClient: await account.authenticate(
          scopes: [PlayServiceAccount.reportingScope],
        ),
      );
      final api = PlayVitalsApi(client: client, packageName: packageName);
      try {
        final freshness = await api.freshness(VitalsMetricSet.crashRate);
        final until = freshness.clamp(
          DateTime.now().toUtc(),
          AggregationPeriod.daily,
        );
        final metrics = await api.query(
          VitalsQuery(
            metricSet: VitalsMetricSet.crashRate,
            metrics: const ['crashRate', 'distinctUsers'],
            from: until.subtract(const Duration(days: 7)),
            to: until,
          ),
        );
        final crashRate = metrics['crashRate'];
        if (crashRate == null) {
          return 'settled to ${_day(until)}; no crash data in the last week';
        }
        return 'settled to ${_day(until)}; ${crashRate.points.length} daily '
            'points, average ${crashRate.average?.toStringAsFixed(5)}';
      } finally {
        api.close();
      }
    }),
  );

  if (bucket == null) {
    results.add(_skip('Google Play report CSVs', 'PLAY_BUCKET'));
  } else {
    results.add(
      await _run('Google Play report CSVs', () async {
        final api = PlayReportsApi(
          client: PlayStorageClient(
            authenticatedClient: await account.authenticate(
              scopes: [PlayServiceAccount.storageReadScope],
            ),
          ),
          bucket: bucket,
          packageName: packageName,
        );
        try {
          // Listing proves the bucket id and the file-name grammar, which is
          // the part reconstructed from documentation rather than an API.
          final names = await api.list(PlayReportType.installs);
          if (names.isEmpty) {
            return 'bucket reachable, but nothing under '
                '"${PlayReportType.installs.objectPrefix(packageName)}" — '
                'check PLAY_PACKAGE matches the app in this account';
          }
          final latest = names.lastWhere(
            (name) => name.endsWith('_country.csv'),
            orElse: () => names.last,
          );
          final table = await api.fetchObject(latest);
          return '${names.length} files; ${latest.split('/').last} has '
              '${table.length} rows, columns: '
              '${table.columns.take(3).join(', ')}…';
        } finally {
          api.close();
        }
      }),
    );
  }

  return results;
}

String _day(DateTime date) => date.toIso8601String().split('T').first;
