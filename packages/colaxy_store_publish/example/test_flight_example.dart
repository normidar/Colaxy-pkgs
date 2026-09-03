// Gives the latest build to a TestFlight group, and — separately, and only
// if asked — submits the App Store version for review.
//
//   dart run example/test_flight_example.dart \
//     6740000000 ABCD123456 <issuer-uuid> secrets/AuthKey.p8 Internal
//
// The submission at the bottom is commented out on purpose. It is the one
// action here that a human cannot quietly undo.

import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length < 5) {
    stderr.writeln('usage: <appId> <keyId> <issuerId> <AuthKey.p8> <group>');
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
    onLog: stdout.writeln,
  );

  try {
    final build = await publisher.builds.latest();
    if (build == null) {
      stderr.writeln('No build to distribute.');
      exitCode = 1;
      return;
    }

    // A build with no export compliance answer sits in
    // MISSING_EXPORT_COMPLIANCE and reaches nobody, while every request
    // involved reports success.
    if (build.usesNonExemptEncryption == null) {
      stdout.writeln('answering export compliance for ${build.version}');
      await publisher.builds.setExportCompliance(
        buildId: build.id,
        usesNonExemptEncryption: false,
      );
    }

    // Tester notes come from the same release_notes.txt the listing uses, but
    // land on a different resource.
    final metadata = FastlaneIosMetadata.forProject('.');
    final notes = <String, String>{};
    for (final locale in metadata.locales()) {
      final text = metadata.listing(locale).releaseNotes;
      if (text != null) notes[locale] = text;
    }

    final detail = await publisher.testFlight.distribute(
      buildId: build.id,
      groupNames: [arguments[4]],
      testerNotes: notes,
    );
    stdout.writeln(detail);

    // Submitting for App Store review is deliberately not part of the above.
    // Uncomment both lines together — preparing without submitting leaves a
    // draft submission, and submitting costs a review cycle to undo.
    //
    // final version = await publisher.versions.editable();
    // final submission = await publisher.reviewSubmissions.prepare(
    //   platform: 'IOS',
    //   appStoreVersionId: version!.id,
    // );
    // await publisher.reviewSubmissions.submit(submission.id);
  } on StoreConsoleException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    publisher.close();
  }
}
