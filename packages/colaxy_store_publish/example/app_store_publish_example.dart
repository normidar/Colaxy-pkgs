// Publishes the fastlane metadata of the project in the current working
// directory to the App Store.
//
//   dart run example/app_store_publish_example.dart \
//     6740000000 ABCD123456 <issuer-uuid> secrets/AuthKey.p8
//
// Note what is missing next to the Google Play example: there is no dry run
// and no commit. App Store Connect has neither, so every write below is live
// the moment it is made.

import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length < 4) {
    stderr.writeln('usage: <appId> <keyId> <issuerId> <AuthKey.p8>');
    exitCode = 64;
    return;
  }

  final publisher = AppStorePublisher.authenticate(
    apiKey: AppStoreApiKey.fromP8File(
      keyId: arguments[1],
      issuerId: arguments[2],
      path: arguments[3],
    ),
    appId: arguments[0],
    onLog: (message) => stderr.writeln('[asc] $message'),
  );

  try {
    // Worth checking before writing: if neither the version nor the app info
    // record is editable, the writes would either fail or — worse — succeed
    // against a record nobody can see.
    final version = await publisher.versions.editable();
    if (version == null) {
      stderr.writeln('No version in PREPARE_FOR_SUBMISSION. Create one first.');
      exitCode = 1;
      return;
    }
    stdout.writeln('writing to version ${version.versionString}');

    final report = await AppStoreMetadataPublisher(
      publisher: publisher,
      metadata: FastlaneIosMetadata.forProject('.'),
      onLog: stdout.writeln,
    ).publish();

    stdout.writeln(report);
    for (final failure in report.failedLocales.entries) {
      // With no transaction, the locales that succeeded stay written.
      stderr.writeln('failed [${failure.key}]: ${failure.value}');
    }
    if (report.hasFailures) exitCode = 1;
  } on StoreConsoleException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    publisher.close();
  }
}
