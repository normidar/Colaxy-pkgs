// A end-to-end tour of the package: the three-legged OAuth 1.0a dance, then
// read and write calls against the authorized account.
//
// Register an app at the Zaim Developers Center to get a consumer key and
// secret, then run:
//
//   dart run example/example.dart
//
// The placeholders below are placeholders. Never commit a real key, secret,
// or token.

import 'dart:io';

import 'package:zaim_api/zaim_api.dart';

const String consumerKey = 'YOUR_CONSUMER_KEY';
const String consumerSecret = 'YOUR_CONSUMER_SECRET';

Future<void> main() async {
  // The public master data needs no credentials at all, so it works before
  // the user has authorized anything.
  final defaults = ZaimClient.defaults();
  try {
    final currencies = await defaults.currencies();
    final jpy = currencies.firstWhere((c) => c.currencyCode == 'JPY');
    stdout.writeln('JPY uses ${jpy.point} decimal places (${jpy.unit}).');
  } finally {
    defaults.close();
  }

  final credentials = await authorize();
  final client = ZaimClient(credentials: credentials);
  try {
    await tour(client);
  } on ZaimAuthException catch (e) {
    // Unless the app was registered as "permanently accessible", the
    // permission expires 24 hours after the user granted it.
    stderr.writeln('Authorization failed: ${e.message}');
  } on ZaimApiException catch (e) {
    stderr.writeln('Zaim said ${e.statusCode}: ${e.message}');
  } finally {
    client.close();
  }
}

/// Runs the three-legged OAuth 1.0a flow with out-of-band (PIN) verification.
Future<ZaimCredentials> authorize() async {
  final flow = ZaimAuthFlow(
    consumerKey: consumerKey,
    consumerSecret: consumerSecret,
  );
  try {
    // Step 1: a temporary token pair.
    final requestToken = await flow.requestToken();

    // Step 2: the user approves in a browser. A Browser App would pass its
    // own callback URL to requestToken() instead of the default 'oob'.
    stdout
      ..writeln('Open this URL and approve the app:')
      ..writeln(flow.authorizationUrl(requestToken))
      ..write('Paste the oauth_verifier shown afterwards: ');
    final verifier = stdin.readLineSync()!.trim();

    // Step 3: long-lived credentials. Persist these, not the request token.
    return await flow.accessToken(requestToken, verifier);
  } finally {
    flow.close();
  }
}

/// Reads the account, then creates, updates, and deletes one payment.
Future<void> tour(ZaimClient client) async {
  // Who are we? Cheap, and needs no scope.
  final me = await client.user.verify();
  stdout.writeln('Signed in as ${me.name} (${me.currencyCode}).');

  // Scope: read.
  final categories = await client.category.list();
  final genres = await client.genre.list();
  final accounts = await client.account.list();
  stdout.writeln(
    '${categories.length} categories, ${genres.length} genres, '
    '${accounts.length} accounts.',
  );

  // Only manually entered records come back; anything Zaim imported from a
  // bank or card is invisible to the API. `limit` maxes out at 100.
  final recent = await client.money.list(
    mode: MoneyMode.payment,
    startDate: DateTime.now().subtract(const Duration(days: 30)),
    endDate: DateTime.now(),
    limit: 100,
  );
  stdout.writeln('${recent.length} payments in the last 30 days.');

  // `listAll` walks pages of 100 for you and streams the results.
  var total = 0;
  await for (final record in client.money.listAll(mode: MoneyMode.payment)) {
    total += record.amount;
  }
  stdout.writeln('All payments ever: $total ${me.currencyCode}.');

  final category = categories.firstWhere((c) => c.mode == MoneyMode.payment);
  final genre = genres.firstWhere((g) => g.categoryId == category.id);

  // Scope: write. Create...
  final created = await client.money.createPayment(
    categoryId: category.id,
    genreId: genre.id,
    amount: 1280,
    date: DateTime.now(),
    fromAccountId: accounts.isEmpty ? null : accounts.first.id,
    name: 'Bento',
    place: 'Corner store',
    comment: 'Written by the zaim_api example',
  );
  stdout.writeln('Created ${created.id} at ${created.place?.name}.');

  // ...update — amount and date are required on every update...
  final updated = await client.money.updatePayment(
    created.id,
    amount: 1300,
    date: DateTime.now(),
    comment: 'Corrected amount',
  );
  stdout.writeln('Updated ${updated.id}.');

  // ...and delete. Delete takes the mode because Zaim keys the endpoint on
  // it; a record you read back carries it as MoneyRecord.mode.
  final deleted = await client.money.delete(MoneyMode.payment, created.id);
  stdout.writeln(
    'Deleted ${deleted.id}; ${deleted.user.inputCount} records remain.',
  );
}
