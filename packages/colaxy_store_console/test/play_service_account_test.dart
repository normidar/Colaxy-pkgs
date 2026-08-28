import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:test/test.dart';

Map<String, dynamic> _key({String type = 'service_account'}) => {
  'type': type,
  'client_email': 'reviews@example.iam.gserviceaccount.com',
  'private_key': '-----BEGIN PRIVATE KEY-----\nx\n-----END PRIVATE KEY-----',
  'project_id': 'example',
};

void main() {
  group('scopes', () {
    test('the three scopes are distinct', () {
      // A token minted for one is rejected by the others' endpoints, so
      // mixing them up produces a 401 that looks like a bad key.
      final scopes = {
        PlayServiceAccount.androidPublisherScope,
        PlayServiceAccount.reportingScope,
        PlayServiceAccount.storageReadScope,
      };

      expect(scopes, hasLength(3));
    });

    test('reporting and storage scopes have their documented values', () {
      expect(
        PlayServiceAccount.reportingScope,
        'https://www.googleapis.com/auth/playdeveloperreporting',
      );
      expect(
        PlayServiceAccount.storageReadScope,
        'https://www.googleapis.com/auth/devstorage.read_only',
      );
    });

    test('rejects an empty scope list', () {
      // Google would answer with an opaque invalid_scope error.
      expect(
        () => PlayServiceAccount(_key()).authenticate(scopes: []),
        throwsArgumentError,
      );
    });
  });

  group('construction', () {
    test('accepts a service-account key', () {
      final account = PlayServiceAccount(_key());

      expect(account.clientEmail, 'reviews@example.iam.gserviceaccount.com');
    });

    test('rejects an OAuth client secret, naming what it got', () {
      // Downloading the wrong JSON from Google Cloud is a common slip.
      expect(
        () => PlayServiceAccount(_key(type: 'authorized_user')),
        throwsA(
          isA<StoreAuthException>()
              .having((e) => e.store, 'store', Store.googlePlay)
              .having((e) => e.message, 'message', contains('authorized_user')),
        ),
      );
    });

    test('rejects a key missing client_email or private_key', () {
      final incomplete = _key()..remove('private_key');

      expect(
        () => PlayServiceAccount(incomplete),
        throwsA(isA<StoreAuthException>()),
      );
    });

    test('fromJsonString parses a key handed over as an env var', () {
      final account = PlayServiceAccount.fromJsonString(jsonEncode(_key()));

      expect(account.clientEmail, 'reviews@example.iam.gserviceaccount.com');
    });

    test('fromJsonString reports malformed JSON as an auth failure', () {
      expect(
        () => PlayServiceAccount.fromJsonString('{not json'),
        throwsA(
          isA<StoreAuthException>().having(
            (e) => e.message,
            'message',
            contains('not valid JSON'),
          ),
        ),
      );
    });

    test('fromJsonString rejects JSON that is not an object', () {
      expect(
        () => PlayServiceAccount.fromJsonString('[]'),
        throwsA(isA<StoreAuthException>()),
      );
    });

    test('fromFile names the missing path', () {
      expect(
        () => PlayServiceAccount.fromFile('nope/play-api.json'),
        throwsA(
          isA<StoreAuthException>().having(
            (e) => e.message,
            'message',
            contains('nope/play-api.json'),
          ),
        ),
      );
    });
  });
}
