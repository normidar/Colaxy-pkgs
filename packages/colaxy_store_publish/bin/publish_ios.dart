// Publishes a fastlane metadata tree to the App Store.
//
//   dart run colaxy_store_publish:publish-ios --doctor
//   dart run colaxy_store_publish:publish-ios
//
// See --help for the environment variables it needs.

import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';

const _usage = '''
Publishes App Store listings and screenshots from a fastlane metadata tree.

Usage: dart run colaxy_store_publish:publish-ios [options]

There is no --dry-run here, and that is not an oversight. Google Play offers
edits.validate; App Store Connect has no equivalent, and a locally-invented
imitation would check different things than the store does. Narrow what a run
touches with --no-app-info, --no-version-text and --no-screenshots instead.

Every write lands immediately. A run that fails halfway leaves the store
half-updated, so failures are collected per locale and reported at the end
rather than aborting the run.

Modes
  --doctor        Check the credentials and report what is writable, then
                  stop. Reads only; nothing is created or changed.
  --upload=FILE   Deliver an .ipa or .pkg, then stop. Needs --version and
                  --short-version: App Store Connect takes both on trust
                  rather than reading them out of the archive.
  --testflight=GROUPS
                  Give the latest build to these TestFlight groups (comma
                  separated), then stop. Writes tester notes from
                  release_notes.txt, and submits for beta review when any
                  group is external — without that, an external group is
                  assigned the build and no tester ever receives it.
  (none)          Write the metadata. This publishes.

There is no submit-for-review flag. Submitting is the one action here that a
human cannot quietly undo, so it stays a deliberate two-line call through
ReviewSubmissionsApi rather than something a CI job can reach by accident.

Options
  --root=DIR      The project directory holding fastlane/ (default: .).
  --locales=a,b   Publish only these locales (default: every one found).
  --no-app-info   Skip the app-wide half: name, subtitle, privacy policy URL.
  --no-version-text
                  Skip the version half: description, keywords, release notes.
  --no-screenshots
                  Skip screenshots.
  --replace-screenshots
                  Empty each screenshot set before uploading into it.
                  DESTRUCTIVE, and one request per existing screenshot —
                  Apple has no bulk delete.
  --no-wait       Do not wait for Apple to finish processing each screenshot.
                  Processing is asynchronous and can reject an asset that
                  uploaded cleanly, so waiting is on by default.
  --platform=IOS  Narrow the version lookup (IOS, MAC_OS, TV_OS, VISION_OS).
  --no-beta-review
                  With --testflight, skip the beta review submission. Leaves
                  external groups without the build.
  --build=NUMBER  With --testflight, pick a build number instead of the
                  most recently uploaded one.
  --version=N     With --upload, the CFBundleVersion to declare.
  --short-version=X.Y.Z
                  With --upload, the CFBundleShortVersionString to declare.

Environment
  ASC_KEY_ID      10-character key ID.
  ASC_ISSUER_ID   Issuer UUID.
  ASC_P8          The .p8 contents, or a path to the file.
  ASC_APP_ID      Numeric app ID from the App Store Connect URL.
  ASC_BUNDLE_ID   Alternative to ASC_APP_ID: the bundle identifier, e.g.
                  com.example.app. Looked up through the API, so a pipeline
                  does not have to carry a numeric id it cannot read off the
                  project.

The key must be a *team* key. An individual key is rejected by several
endpoints — colaxy_store_console found the same on the sales reports.

Exit codes
  0  done
  1  the store rejected something, or a locale failed
  64 wrong arguments or missing credentials
''';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write(_usage);
    return;
  }

  final unknown = args.where(
    (arg) =>
        !arg.startsWith('--root=') &&
        !arg.startsWith('--locales=') &&
        !arg.startsWith('--platform=') &&
        !arg.startsWith('--testflight=') &&
        !arg.startsWith('--build=') &&
        !arg.startsWith('--upload=') &&
        !arg.startsWith('--version=') &&
        !arg.startsWith('--short-version=') &&
        !const {
          '--doctor',
          '--no-app-info',
          '--no-version-text',
          '--no-screenshots',
          '--replace-screenshots',
          '--no-wait',
          '--no-beta-review',
        }.contains(arg),
  );
  if (unknown.isNotEmpty) {
    stderr
      ..writeln('Unknown argument: ${unknown.first}')
      ..writeln('Run with --help.');
    exitCode = 64;
    return;
  }

  final keyId = _env('ASC_KEY_ID');
  final issuerId = _env('ASC_ISSUER_ID');
  final p8 = _env('ASC_P8');
  final bundleId = _env('ASC_BUNDLE_ID');
  var appId = _env('ASC_APP_ID');
  if (keyId == null || issuerId == null || p8 == null ||
      (appId == null && bundleId == null)) {
    stderr
      ..writeln(
        'ASC_KEY_ID, ASC_ISSUER_ID, ASC_P8 and one of ASC_APP_ID / '
        'ASC_BUNDLE_ID are required.',
      )
      ..writeln('Run with --help.');
    exitCode = 64;
    return;
  }

  final AppStoreApiKey apiKey;
  try {
    apiKey = _apiKey(keyId: keyId, issuerId: issuerId, p8: p8);
  } on StoreConsoleException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
    return;
  }

  if (appId == null) {
    // Resolving the numeric id from the bundle identifier keeps one less
    // piece of configuration in the pipeline: the bundle id is in the
    // project, the numeric id is only in a URL.
    final lookup = AppStoreConnectClient(apiKey: apiKey);
    try {
      final apps = await lookup
          .resources('/v1/apps', query: {'filter[bundleId]': bundleId})
          .toList();
      final match = apps
          .where(
            (a) =>
                (a['attributes'] as Map<String, dynamic>?)?['bundleId'] ==
                bundleId,
          )
          .toList();
      if (match.isEmpty) {
        stderr.writeln(
          'No App Store app with bundle id "$bundleId" is visible to this '
          'key. Check the bundle id, and that the key reaches the right team.',
        );
        exitCode = 1;
        return;
      }
      appId = match.first['id'] as String;
      stdout.writeln('Resolved $bundleId to app $appId');
    } on StoreConsoleException catch (error) {
      stderr.writeln(error);
      exitCode = 1;
      return;
    } finally {
      lookup.close();
    }
  }

  final AppStorePublisher publisher;
  try {
    publisher = AppStorePublisher.authenticate(
      apiKey: apiKey,
      appId: appId,
      onLog: (message) => stderr.writeln('[asc] $message'),
    );
  } on StoreConsoleException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
    return;
  }

  final metadata = FastlaneIosMetadata.forProject(
    _option(args, '--root=') ?? '.',
  );

  try {
    if (args.contains('--doctor')) {
      await _doctor(publisher, metadata);
      return;
    }

    final archive = _option(args, '--upload=');
    if (archive != null) {
      await _upload(
        publisher,
        path: archive,
        version: _option(args, '--version='),
        shortVersion: _option(args, '--short-version='),
        platform: _option(args, '--platform=') ?? 'IOS',
      );
      return;
    }

    final groups = _option(args, '--testflight=');
    if (groups != null) {
      await _testFlight(
        publisher,
        metadata,
        groupNames: _locales(groups)?.toList() ?? const [],
        buildNumber: _option(args, '--build='),
        submitForBetaReview: !args.contains('--no-beta-review'),
      );
      return;
    }

    final report = await AppStoreMetadataPublisher(
      publisher: publisher,
      metadata: metadata,
      options: AppStorePublishOptions(
        locales: _locales(_option(args, '--locales=')),
        publishAppInfo: !args.contains('--no-app-info'),
        publishVersionText: !args.contains('--no-version-text'),
        publishScreenshots: !args.contains('--no-screenshots'),
        replaceScreenshots: args.contains('--replace-screenshots'),
        awaitProcessing: !args.contains('--no-wait'),
        platform: _option(args, '--platform='),
      ),
      onLog: stdout.writeln,
    ).publish();

    stdout.writeln(report);
    for (final path in report.unmappedScreenshots) {
      stderr.writeln(
        'skipped: no App Store device slot for this capture name\n    $path',
      );
    }
    for (final failure in report.failedLocales.entries) {
      stderr.writeln('failed [${failure.key}]: ${failure.value}');
    }
    if (report.isEmpty) {
      stdout.writeln('Nothing was written — check the metadata directory.');
    }
    if (report.hasFailures) exitCode = 1;
  } on StoreConsoleException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    publisher.close();
  }
}

/// Delivers a binary to App Store Connect.
///
/// The versions are required because Apple takes them on trust — nothing
/// reads them out of the archive, so leaving them off would mean guessing.
Future<void> _upload(
  AppStorePublisher publisher, {
  required String path,
  required String? version,
  required String? shortVersion,
  required String platform,
}) async {
  if (version == null || shortVersion == null) {
    stderr.writeln(
      '--upload needs --version and --short-version. App Store Connect takes '
      'both on trust rather than reading them out of the archive, so there '
      'is nothing sensible to default them to.',
    );
    exitCode = 64;
    return;
  }

  final upload = await publisher.buildUploads.upload(
    file: File(path),
    cfBundleVersion: version,
    cfBundleShortVersionString: shortVersion,
    platform: platform,
  );
  stdout.writeln(upload);
  for (final warning in upload.warnings) {
    stderr.writeln('warning: $warning');
  }
  if (!upload.isComplete) {
    stderr.writeln(
      'The upload did not reach COMPLETE. It may still be processing; check '
      'again before distributing.',
    );
    exitCode = 1;
  }
}

/// Gives a build to TestFlight groups, with the tester notes from disk.
///
/// The release notes come from the same `release_notes.txt` the App Store
/// listing uses, but they are a different field on a different resource —
/// two writes, not one.
Future<void> _testFlight(
  AppStorePublisher publisher,
  FastlaneIosMetadata metadata, {
  required List<String> groupNames,
  required bool submitForBetaReview,
  String? buildNumber,
}) async {
  if (groupNames.isEmpty) {
    stderr.writeln('--testflight needs at least one group name.');
    exitCode = 64;
    return;
  }

  final build = await publisher.builds.latest(version: buildNumber);
  if (build == null) {
    stderr.writeln(
      buildNumber == null
          ? 'No build found. Upload one first — this package cannot yet, '
                'though the API can (buildUploads).'
          : 'No build numbered $buildNumber.',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln('build ${build.version} (${build.processingState})');

  final notes = <String, String>{};
  try {
    for (final locale in metadata.locales()) {
      final text = metadata.listing(locale).releaseNotes;
      if (text != null) notes[locale] = text;
    }
  } on StoreConsoleException {
    // No metadata tree is fine here: distributing a build does not need one.
  }

  final detail = await publisher.testFlight.distribute(
    buildId: build.id,
    groupNames: groupNames,
    testerNotes: notes,
    submitForBetaReview: submitForBetaReview,
  );
  stdout.writeln(detail ?? 'distributed; Apple reported no TestFlight state');
}

/// Reports what the credentials reach, without writing anything.
///
/// Deliberately read-only, unlike the Google Play doctor: there is no edit to
/// open and discard here, so proving write permission would mean making a
/// change that cannot be taken back.
Future<void> _doctor(
  AppStorePublisher publisher,
  FastlaneIosMetadata metadata,
) async {
  final version = await publisher.versions.editable();
  stdout.writeln(
    version == null
        ? 'FAIL   editable version         none in PREPARE_FOR_SUBMISSION'
        : 'PASS   editable version         ${version.id} '
              '(${version.versionString ?? '?'})',
  );

  final appInfo = await publisher.appInfos.editable();
  stdout.writeln(
    appInfo == null
        ? 'FAIL   editable app info        none; app-wide text is locked'
        : 'PASS   editable app info        ${appInfo.id}',
  );

  if (version != null) {
    final locales = await publisher.versionLocalizations(version).list();
    stdout.writeln(
      'PASS   store locales            '
      '${locales.map((l) => l.locale).join(', ')}',
    );
  }

  try {
    final local = metadata.locales();
    stdout.writeln('PASS   local locales            ${local.join(', ')}');
    for (final locale in local) {
      final unmapped = metadata.unmappedScreenshots(locale);
      if (unmapped.isEmpty) continue;
      stdout.writeln(
        'WARN   unplaceable screenshots  $locale: ${unmapped.length} '
        'file(s) with no device slot',
      );
    }
  } on StoreConsoleException catch (error) {
    stdout.writeln('FAIL   local locales            ${error.message}');
  }

  final groups = await publisher.betaGroups.list();
  stdout.writeln(
    groups.isEmpty
        ? 'WARN   TestFlight groups        none'
        : 'PASS   TestFlight groups        '
              '${groups.map((g) => '${g.name}'
                  '${g.needsBetaReview ? ' (external)' : ''}').join(', ')}',
  );

  if (version == null || appInfo == null) exitCode = 1;
}

/// The value of `--name=value`, or `null` when the flag is absent.
String? _option(List<String> args, String prefix) {
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  return null;
}

/// The value of `name` in the environment, or `null` when unset or blank.
String? _env(String name) {
  final value = Platform.environment[name]?.trim();
  return value == null || value.isEmpty ? null : value;
}

Set<String>? _locales(String? value) {
  if (value == null) return null;
  final names = value
      .split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toSet();
  return names.isEmpty ? null : names;
}

/// Builds a key from `ASC_P8` holding either the PEM or a path to it.
///
/// The same accommodation `colaxy_store_console`'s verify tool makes: both
/// are natural things to put in an environment variable, and a PEM always
/// carries its `-----BEGIN` header, so telling them apart is unambiguous.
AppStoreApiKey _apiKey({
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
