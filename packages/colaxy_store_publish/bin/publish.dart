// Publishes a fastlane metadata tree to Google Play, or checks one without
// touching the network.
//
//   dart run colaxy_store_publish:publish --check
//   dart run colaxy_store_publish:publish --dry-run
//   dart run colaxy_store_publish:publish
//
// See --help for the environment variables it needs.

import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';

const _usage = '''
Publishes Google Play listings and images from a fastlane metadata tree.

Usage: dart run colaxy_store_publish:publish [options]

For the App Store, use `dart run colaxy_store_publish:publish-ios`. The two
are separate commands because the stores are separate shapes: Google Play
publishes through a transaction that can be validated and discarded, and the
App Store writes immediately. A single command would have to pretend the
difference away.

Modes
  --check         Check the local tree and stop. Makes no network calls, needs
                  no credentials. Safe in a pre-commit hook.
  --doctor        Check the credentials, the permissions and what the store
                  already has, then stop. Opens an edit and discards it, which
                  is the only way to prove edit permission — reading a listing
                  succeeds for an account that could never publish. Nothing
                  else is written and nothing is committed.
  --upload=FILE   Upload an .aab and commit the edit, then stop. Metadata and
                  screenshots are not touched, and **no track is released**,
                  so the bundle lands in Play Console as an artifact and
                  reaches no user. Releasing it is a separate, deliberate
                  step through PlayTracksApi.
  --dry-run       Stage every change in a Play edit, have Google validate it,
                  then discard. Nothing reaches the store. Combines with
                  --upload to check a bundle without keeping it.
  (none)          Stage the changes and commit the edit. This publishes.

Options
  --metadata=DIR  The fastlane/metadata/android directory
                  (default: ./fastlane/metadata/android).
  --locales=a,b   Publish only these locales (default: every one found).
  --replace-screenshots
                  Empty each screenshot slot before uploading into it.
                  DESTRUCTIVE: screenshots on the store that do not exist
                  locally are lost. Off by default, so uploads append.
  --feature-graphic
                  Also upload android/featureGraphic.png — the file
                  colaxy_screenshot writes outside the fastlane layout — to
                  every published locale. Off by default.
  --error-if-in-review
                  Refuse to commit while the app has changes under review.
                  Google's default is to CANCEL that review and resubmit, so
                  a routine metadata push can restart a release's review
                  clock. Recommended for unattended runs.
  --skip-check    Publish even if the local check found blocking problems.
  --allow-empty   Commit even when nothing was staged. Committing an empty
                  edit still cancels a review in progress, so this is off.

Environment
  PLAY_KEY_JSON   The service-account JSON, or a path to the file.
  PLAY_PACKAGE    Application ID, e.g. com.example.app.

Both are needed unless --check is passed.

The service account must be invited in Play Console under Users and
permissions, with "Edit and delete draft apps". Note that the androidpublisher
OAuth scope has no read-only variant: a key used to read reviews already had
the ability to publish.

Exit codes
  0  done
  1  the store rejected something, or the local check found errors
  64 wrong arguments or missing credentials
''';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write(_usage);
    return;
  }

  final unknown = args.where(
    (arg) =>
        !arg.startsWith('--metadata=') &&
        !arg.startsWith('--locales=') &&
        !arg.startsWith('--upload=') &&
        !const {
          '--check',
          '--doctor',
          '--dry-run',
          '--replace-screenshots',
          '--feature-graphic',
          '--error-if-in-review',
          '--skip-check',
          '--allow-empty',
        }.contains(arg),
  );
  if (unknown.isNotEmpty) {
    stderr
      ..writeln('Unknown argument: ${unknown.first}')
      ..writeln('Run with --help.');
    exitCode = 64;
    return;
  }

  final checkOnly = args.contains('--check');
  final doctorOnly = args.contains('--doctor');
  final dryRun = args.contains('--dry-run');
  final bundlePath = _option(args, '--upload=');
  final metadata = _metadata(_option(args, '--metadata='));
  final locales = _locales(_option(args, '--locales='));

  final options = PlayPublishOptions(
    locales: locales,
    replaceScreenshots: args.contains('--replace-screenshots'),
    uploadStrayFeatureGraphic: args.contains('--feature-graphic'),
  );

  // A bundle upload never reads the metadata tree, so checking it would only
  // report problems the run cannot cause — and, worse, refuse to proceed over
  // them. `--doctor` has the same shape and is handled below.
  final readsMetadata = bundlePath == null;

  var blocking = 0;
  if (readsMetadata) {
    final issues = MetadataCheck(metadata: metadata, options: options).run()
      ..forEach(stderr.writeln);
    blocking = issues.where((issue) => issue.severity.blocks).length;
    stdout.writeln(
      'Check: ${_count(blocking, 'error')}, '
      '${_count(issues.length - blocking, 'warning')}.',
    );
  }

  if (checkOnly) {
    if (blocking > 0) exitCode = 1;
    return;
  }
  // The doctor is about the account, not the tree, so a broken tree must not
  // stop it — a missing metadata directory is the most likely reason someone
  // is checking their credentials in the first place.
  if (blocking > 0 && !doctorOnly && !args.contains('--skip-check')) {
    stderr.writeln(
      'Refusing to publish with ${_count(blocking, 'blocking problem')}. '
      'Fix them, or pass --skip-check.',
    );
    exitCode = 1;
    return;
  }

  final keyJson = _env('PLAY_KEY_JSON');
  final packageName = _env('PLAY_PACKAGE');
  if (keyJson == null || packageName == null) {
    stderr
      ..writeln('PLAY_KEY_JSON and PLAY_PACKAGE are both required.')
      ..writeln('Run with --help, or with --check to skip credentials.');
    exitCode = 64;
    return;
  }

  final PlayPublisher publisher;
  try {
    publisher = await PlayPublisher.authenticate(
      account: _account(keyJson),
      packageName: packageName,
      guard: PlayApiGuard(
        onLog: (message) => stderr.writeln('[play] $message'),
      ),
    );
  } on StoreConsoleException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
    return;
  }

  if (doctorOnly) {
    final checks = await PlayDoctor(
      publisher: publisher,
      metadata: metadata,
    ).run();
    publisher.close();

    stdout.writeln();
    checks.forEach(stdout.writeln);
    final failed = checks
        .where((check) => check.outcome == DoctorOutcome.fail)
        .length;
    stdout.writeln('\n${_count(failed, 'failure')}.');
    if (failed > 0) exitCode = 1;
    return;
  }

  if (bundlePath != null) {
    await _uploadBundle(
      publisher,
      path: bundlePath,
      dryRun: dryRun,
      changesInReviewBehavior: args.contains('--error-if-in-review')
          ? ChangesInReviewBehavior.errorIfInReview
          : null,
    );
    publisher.close();
    return;
  }

  final metadataPublisher = PlayMetadataPublisher(
    metadata: metadata,
    options: options,
    onLog: stdout.writeln,
  );

  try {
    // The edit is driven by hand rather than through `publisher.edit`, because
    // whether to commit depends on what got staged: committing an edit that
    // staged nothing still cancels a review in progress.
    final session = await publisher.openEdit();
    stdout.writeln(
      'Opened edit ${session.editId}'
      '${session.expiresAt == null ? '' : ', expires ${session.expiresAt}'}',
    );

    final PlayPublishReport report;
    try {
      report = await metadataPublisher.publish(session);
    } on Object {
      await session.discardQuietly();
      rethrow;
    }
    stdout.writeln(report);

    if (report.isEmpty && !args.contains('--allow-empty')) {
      stdout.writeln('Nothing was staged; discarding the edit.');
      await session.discard();
      return;
    }
    if (dryRun) {
      await session.validate();
      stdout.writeln('Google validated the staged changes. Discarding.');
      await session.discard();
      return;
    }

    await session.commit(
      changesInReviewBehavior: args.contains('--error-if-in-review')
          ? ChangesInReviewBehavior.errorIfInReview
          : null,
    );
    stdout.writeln('Committed. The changes are live or queued for review.');
  } on StoreConsoleException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    publisher.close();
  }
}

/// Uploads an app bundle and commits, **without releasing it to a track**.
///
/// Committing an edit that holds only a bundle puts the artifact in Play
/// Console and gives it to nobody: a build reaches users when a *track* names
/// its version code, which is a separate call this deliberately does not
/// make. That separation is what makes "upload now, decide later" possible on
/// Google Play, and it has no App Store equivalent.
Future<void> _uploadBundle(
  PlayPublisher publisher, {
  required String path,
  required bool dryRun,
  ChangesInReviewBehavior? changesInReviewBehavior,
}) async {
  final file = File(path);
  final session = await publisher.openEdit();
  stdout.writeln(
    'Opened edit ${session.editId}'
    '${session.expiresAt == null ? '' : ', expires ${session.expiresAt}'}',
  );

  final PlayBundle bundle;
  try {
    bundle = await session.bundles.upload(file);
  } on Object {
    await session.discardQuietly();
    rethrow;
  }
  stdout.writeln('Uploaded version code ${bundle.versionCode}');

  if (dryRun) {
    await session.validate();
    stdout.writeln('Google validated the bundle. Discarding.');
    await session.discard();
    return;
  }

  try {
    await session.commit(changesInReviewBehavior: changesInReviewBehavior);
  } on Object {
    await session.discardQuietly();
    rethrow;
  }
  stdout
    ..writeln('Committed. The bundle is in Play Console.')
    ..writeln(
      'It is released to no track, so no user has it. Put it on a track '
      'deliberately when you want that.',
    );
}

/// `1 error` / `2 errors`, so a one-problem run does not read as broken.
String _count(int amount, String noun) =>
    '$amount $noun${amount == 1 ? '' : 's'}';

/// The value of `--name=value`, or `null` when the flag is absent.
String? _option(List<String> args, String prefix) {
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  return null;
}

/// The value of `name` in the environment, or `null` when unset or blank.
///
/// A blank value means "not configured": sourcing a `.env` template sets every
/// variable, and treating an untouched line as present turns it into a
/// confusing failure.
String? _env(String name) {
  final value = Platform.environment[name]?.trim();
  return value == null || value.isEmpty ? null : value;
}

FastlaneMetadata _metadata(String? path) => path == null
    ? FastlaneMetadata.forProject('.')
    : FastlaneMetadata(Directory(path));

Set<String>? _locales(String? value) {
  if (value == null) return null;
  final names = value
      .split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toSet();
  return names.isEmpty ? null : names;
}

/// Builds an account from `PLAY_KEY_JSON` holding either the key or a path.
///
/// The same accommodation `colaxy_store_console`'s verify tool makes, for the
/// same reason: both are natural things to put in an environment variable,
/// and a service-account key always starts with `{`, so telling them apart is
/// unambiguous.
PlayServiceAccount _account(String keyJson) {
  final value = keyJson.trim();
  if (value.startsWith('{')) return PlayServiceAccount.fromJsonString(value);
  if (File(value).existsSync()) return PlayServiceAccount.fromFile(value);
  throw StoreAuthException(
    'PLAY_KEY_JSON is neither JSON nor a readable file: ${value.length} '
    'characters, no leading "{", and no file at that path. Set it to the '
    r'contents — PLAY_KEY_JSON="$(cat play-api.json)" — or to a path that '
    'exists.',
    store: Store.googlePlay,
  );
}
