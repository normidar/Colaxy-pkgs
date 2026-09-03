// Publishes the fastlane metadata directory of the project in the current
// working directory to Google Play, and commits the edit.
//
//   dart run example/colaxy_store_publish_example.dart \
//     com.example.app secrets/play-api.json
//
// Pass --dry-run as a third argument to have Google validate the staged
// changes and then throw them away.

import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length < 2) {
    stderr.writeln('usage: <packageName> <serviceAccount.json> [--dry-run]');
    exitCode = 64;
    return;
  }
  final packageName = arguments[0];
  final dryRun = arguments.contains('--dry-run');

  final publisher = await PlayPublisher.authenticate(
    account: PlayServiceAccount.fromFile(arguments[1]),
    packageName: packageName,
    guard: PlayApiGuard(onLog: (message) => stderr.writeln('[play] $message')),
  );

  final metadata = PlayMetadataPublisher(
    metadata: FastlaneMetadata.forProject('.'),
    onLog: stdout.writeln,
  );

  try {
    final report = await publisher.edit(
      metadata.publish,
      dryRun: dryRun,
      // Refuse to disturb a review already in flight. Google's own default
      // would cancel it and restart the clock.
      changesInReviewBehavior: ChangesInReviewBehavior.errorIfInReview,
    );
    stdout.writeln(report);
    if (report.isEmpty) {
      stdout.writeln('Nothing to publish — check the metadata directory.');
    }
  } on StoreConsoleException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    publisher.close();
  }
}
