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
enum _Outcome {
  /// The API answered with data this package parsed.
  pass,

  /// The API answered, but with nothing to parse — no sales that day, no
  /// report generated yet.
  ///
  /// Distinct from [pass] on purpose. The credentials and the request shape
  /// are proven; the decoding is not. Reporting it as a pass would claim a
  /// verification that did not happen.
  empty,

  /// The API rejected the request, or this package could not read the answer.
  fail,

  /// Not attempted, for want of credentials.
  skip,
}

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
    ASC_P8             the .p8 contents, or a path to the file
    ASC_APP_ID         numeric app ID from the App Store Connect URL

  App Store sales reports
    ASC_KEY_ID, ASC_ISSUER_ID, ASC_P8
    ASC_VENDOR_NUMBER  from Payments and Financial Reports

  Note the key must be a *team* key: an individual key cannot reach the sales
  endpoints whatever its role. Reviews want Customer Support or Admin; sales
  want Sales, Finance or Admin.

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
    Registering needs an Admin key; collecting afterwards does not.

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
      _Outcome.pass => 'PASS ',
      _Outcome.empty => 'EMPTY',
      _Outcome.fail => 'FAIL ',
      _Outcome.skip => 'SKIP ',
    };
    stdout.writeln('$tag  ${result.name.padRight(34)} ${result.detail}');
  }

  int count(_Outcome outcome) =>
      results.where((r) => r.outcome == outcome).length;
  final failed = count(_Outcome.fail);
  final empty = count(_Outcome.empty);
  final skipped = count(_Outcome.skip);
  stdout.writeln(
    '\n${count(_Outcome.pass)} passed, $empty empty, $failed failed, '
    '$skipped skipped.',
  );

  if (empty > 0) {
    stdout.writeln(
      'EMPTY means the store answered but had no data — the credentials and '
      'the request are good, the decoding is still unproven.',
    );
  }
  if (skipped > 0) {
    stdout.writeln(
      'SKIP means not checked at all. Supply those credentials before '
      'trusting the surface.',
    );
  }
  if (failed > 0) exit(1);
}

/// Runs one check, turning any failure into a readable result.
///
/// A verification tool that dies on the first error tells you less than one
/// that reports every surface, so nothing is allowed to escape.
/// Prefix a check's message with this to report [_Outcome.empty].
const _emptyMarker = 'EMPTY:';

Future<_Result> _run(String name, Future<String> Function() check) async {
  // Progress goes to a terminal only. Piped or redirected, the carriage
  // returns would leave half-erased lines in the output.
  final live = stdout.hasTerminal;
  if (live) stdout.write('${'… $name'.padRight(60)}\r');
  try {
    final detail = await check();
    return detail.startsWith(_emptyMarker)
        ? _Result(name, _Outcome.empty, detail.substring(_emptyMarker.length))
        : _Result(name, _Outcome.pass, detail);
  } on StoreConsoleException catch (error) {
    // These already carry a message naming the likely setup mistake.
    return _Result(name, _Outcome.fail, error.toString());
  } on Object catch (error) {
    return _Result(name, _Outcome.fail, '$error');
  } finally {
    if (live) stdout.write('${' ' * 60}\r');
  }
}

/// The value of `name` in `env`, or `null` when unset or blank.
String? _value(Map<String, String> env, String name) {
  final value = env[name]?.trim();
  return value == null || value.isEmpty ? null : value;
}

_Result _skip(String name, String missing) =>
    _Result(name, _Outcome.skip, 'needs $missing');

/// Builds a key from `ASC_P8` holding either the PEM or a path to it.
///
/// Both are natural things to put in an environment variable, and telling
/// them apart is unambiguous: a PEM always carries its `-----BEGIN` header.
/// Guessing here is safe, and saves a confusing failure — a path handed
/// straight to [AppStoreApiKey] fails as "does not look like PEM", which does
/// not suggest the fix.
AppStoreApiKey _appStoreKey({
  required String keyId,
  required String issuerId,
  required String p8,
}) {
  final value = p8.trim();
  if (value.contains('-----BEGIN')) {
    return AppStoreApiKey(keyId: keyId, issuerId: issuerId, privateKey: value);
  }
  if (File(value).existsSync()) {
    return AppStoreApiKey.fromP8File(
      keyId: keyId,
      issuerId: issuerId,
      path: value,
    );
  }
  throw StoreAuthException(
    'ASC_P8 is neither PEM nor a readable file: ${value.length} characters, '
    'no "-----BEGIN" header, and no file at that path. Set it to the '
    r'contents of the .p8 — ASC_P8="$(cat AuthKey_....p8)" — or to a path '
    'that exists.',
    store: Store.appStore,
  );
}

Future<List<_Result>> _appStoreChecks(
  Map<String, String> env, {
  required bool allowWrites,
}) async {
  // A blank value means "not configured". Sourcing a .env template sets every
  // variable, so treating an empty one as present turns an untouched line
  // into a spurious failure.
  final keyId = _value(env, 'ASC_KEY_ID');
  final issuerId = _value(env, 'ASC_ISSUER_ID');
  final p8 = _value(env, 'ASC_P8');
  final appId = _value(env, 'ASC_APP_ID');
  final vendorNumber = _value(env, 'ASC_VENDOR_NUMBER');

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
      key = _appStoreKey(keyId: keyId, issuerId: issuerId, p8: p8);
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
            return '${_emptyMarker}no report request registered; rerun with '
                '--allow-writes to create one';
          }
          final request = allowWrites
              ? await console.analytics.ensureRequest(
                  AnalyticsAccessType.ongoing,
                )
              : requests.first;

          final reports = await console.analytics.reports(request.id);
          if (reports.isEmpty) {
            return '${_emptyMarker}request ${request.id} exists, no reports '
                'yet — Apple takes 24-48 hours';
          }
          // The chain past this point is what the mocked tests cannot prove.
          final instances = await console.analytics.instances(reports.first.id);
          if (instances.isEmpty) {
            return '$_emptyMarker${reports.length} reports, none generated '
                'yet';
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
          // Widening until something has data, because decoding a real
          // report is the point — a quiet day proves only that the request
          // was accepted. Yesterday first: today's report does not exist yet.
          final now = DateTime.now().toUtc();
          final periods = <String, SalesReportQuery>{
            'yesterday': SalesReportQuery.sales(
              date: DateTime.utc(now.year, now.month, now.day - 1),
            ),
            'last month': SalesReportQuery.sales(
              frequency: SalesFrequency.monthly,
              date: DateTime.utc(now.year, now.month - 1),
            ),
            'last year': SalesReportQuery.sales(
              frequency: SalesFrequency.yearly,
              date: DateTime.utc(now.year - 1),
            ),
          };

          for (final period in periods.entries) {
            final table = await team.salesReports.fetch(period.value);
            if (table.columns.isEmpty) continue;

            // Every column is optional across report versions, so report
            // what actually parsed rather than asserting on any one.
            final unreadableDates = table.entries
                .where((row) => row.dateAt('Begin Date') == null)
                .length;
            final units = table.entries.fold<int>(
              0,
              (sum, row) => sum + (row.intAt('Units') ?? 0),
            );
            return '${table.length} rows, ${table.columns.length} columns for '
                '${period.key}; $units units'
                '${unreadableDates == 0 ? '' : ', $unreadableDates unparsed '
                          'dates'}';
          }
          return '${_emptyMarker}requests accepted, but no sales in any of: '
              '${periods.keys.join(', ')}';
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
              ? '${_emptyMarker}accepted the request — the version/frequency '
                    'pairing is right — but no data for last year'
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
  final keyJson = _value(env, 'PLAY_KEY_JSON');
  final packageName = _value(env, 'PLAY_PACKAGE');
  final bucket = _value(env, 'PLAY_BUCKET');

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
            ? '${_emptyMarker}no reviews in the last seven days — the API '
                  'reaches no further'
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
          return '${_emptyMarker}settled to ${_day(until)}; no crash data in '
              'the last week';
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
            return '${_emptyMarker}bucket reachable, but nothing under '
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
