// Uploads an app bundle and puts it on the internal testing track, with the
// release notes that colaxy_localization generated.
//
//   dart run example/play_release_example.dart \
//     com.example.app secrets/play-api.json build/app/.../app-release.aab

import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length < 3) {
    stderr.writeln('usage: <packageName> <serviceAccount.json> <app.aab>');
    exitCode = 64;
    return;
  }

  final publisher = await PlayPublisher.authenticate(
    account: PlayServiceAccount.fromFile(arguments[1]),
    packageName: arguments[0],
  );
  final metadata = FastlaneMetadata.forProject('.');

  try {
    await publisher.edit((session) async {
      // Google reads the version code out of the bundle's manifest, so the
      // upload is also how we learn which one we just built.
      final bundle = await session.bundles.upload(File(arguments[2]));
      final versionCode = bundle.versionCode;
      if (versionCode == null) {
        throw StateError('Google Play returned no version code.');
      }
      stdout.writeln('uploaded version code $versionCode');

      // changelogs/<versionCode>.txt where it exists, changelogs/default.txt
      // everywhere else.
      final notes = <String, String>{};
      for (final locale in metadata.locales()) {
        final text = metadata.listing(locale).changelogFor(versionCode);
        if (text != null) notes[locale] = text;
      }

      await session.tracks.release(
        track: PlayTrack.internal,
        versionCodes: [versionCode],
        releaseNotes: notes,
      );
    });
    stdout.writeln('released to the internal track');
  } on StoreConsoleException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    publisher.close();
  }
}
