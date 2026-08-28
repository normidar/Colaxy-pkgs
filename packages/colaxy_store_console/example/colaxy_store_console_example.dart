// Answers unreplied 1- and 2-star reviews on both stores.
//
// Run it with the credentials in the environment:
//
//   PLAY_KEY_JSON="$(cat play-api.json)" \
//   ASC_KEY_ID=ABCD123456 \
//   ASC_ISSUER_ID=69a6de70-0000-0000-0000-1f2c3d4e5f60 \
//   ASC_P8="$(cat AuthKey_ABCD123456.p8)" \
//   dart run example/colaxy_store_console_example.dart
import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';

const packageName = 'com.example.app';
const appId = '6740000000';

Future<void> main() async {
  final env = Platform.environment;

  final console = await StoreConsole.connect(
    playAccount: env['PLAY_KEY_JSON'] == null
        ? null
        : PlayServiceAccount.fromJsonString(env['PLAY_KEY_JSON']!),
    packageName: packageName,
    appStoreKey: env['ASC_P8'] == null
        ? null
        : AppStoreApiKey(
            keyId: env['ASC_KEY_ID']!,
            issuerId: env['ASC_ISSUER_ID']!,
            privateKey: env['ASC_P8']!,
          ),
    appId: appId,
  );

  // `hasReply: false` is server-side on the App Store and applied per page on
  // Google Play, so either way only unanswered reviews come through.
  const needsAnswer = ReviewQuery(ratings: {1, 2}, hasReply: false);

  try {
    await for (final review in console.reviews.list(needsAnswer)) {
      stdout.writeln(
        '${review.store.displayName} ${review.rating}* '
        '${review.authorName ?? "anonymous"}: ${review.body}',
      );

      // Replying through the owning store's API skips the lookup that
      // `console.reviews.reply` would otherwise have to do first.
      final api = review.store == Store.googlePlay
          ? console.googlePlay!.reviews
          : console.appStore!.reviews;

      try {
        final reply = await api.reply(
          review.id,
          'Sorry about the trouble — please write to support@example.com and '
          'we will get this sorted.',
        );
        stdout.writeln('  replied (${reply.state.name})');
      } on StoreRateLimitException catch (error) {
        stderr.writeln('  quota exhausted: ${error.message}');
        break;
      }
    }
  } finally {
    console.close();
  }
}
