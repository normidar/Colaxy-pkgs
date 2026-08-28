import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:test/test.dart';

import 'test_api_key.dart';

Map<String, dynamic> _segment(String token, int index) {
  final part = token.split('.')[index];
  final padded = part.padRight((part.length + 3) ~/ 4 * 4, '=');
  return jsonDecode(utf8.decode(base64Url.decode(padded)))
      as Map<String, dynamic>;
}

void main() {
  group('AppStoreTokenProvider', () {
    test('signs a token with the header and claims Apple requires', () {
      final token = AppStoreTokenProvider(
        testApiKey(),
        clock: () => DateTime.utc(2026, 8, 20, 12),
      ).token();

      final header = _segment(token, 0);
      expect(header['alg'], 'ES256');
      expect(header['typ'], 'JWT');
      expect(header['kid'], 'ABCD123456');

      final claims = _segment(token, 1);
      expect(claims['iss'], '69a6de70-0000-0000-0000-1f2c3d4e5f60');
      expect(claims['aud'], 'appstoreconnect-v1');
      expect((claims['exp'] as int) - (claims['iat'] as int), 20 * 60);
    });

    test('reuses the cached token while it is still valid', () {
      // Re-signing per request costs a full ECDSA operation, so the cache is
      // the point of this class, not an optimisation detail.
      final provider = AppStoreTokenProvider(testApiKey());

      expect(provider.token(), provider.token());
    });

    test('signs a fresh token once the cached one nears expiry', () {
      var now = DateTime.utc(2026, 8, 20, 12);
      final provider = AppStoreTokenProvider(testApiKey(), clock: () => now);

      final first = provider.token();
      now = now.add(const Duration(minutes: 18));
      expect(provider.token(), first, reason: 'still inside the margin');

      // 19 minutes in, the token has one minute left — short enough that a
      // request using it could arrive after it expired.
      now = now.add(const Duration(minutes: 1));
      expect(provider.token(), isNot(first));
    });

    test('invalidate() forces the next call to re-sign', () {
      var now = DateTime.utc(2026, 8, 20, 12);
      final provider = AppStoreTokenProvider(testApiKey(), clock: () => now);
      final first = provider.token();

      provider.invalidate();
      now = now.add(const Duration(seconds: 1));

      expect(provider.token(), isNot(first));
    });

    test('rejects a lifetime longer than Apple accepts', () {
      expect(
        () => AppStoreTokenProvider(
          testApiKey(),
          lifetime: const Duration(minutes: 21),
        ),
        throwsArgumentError,
      );
    });

    test('reports an unusable key as a StoreAuthException', () {
      final provider = AppStoreTokenProvider(
        AppStoreApiKey(
          keyId: 'ABCD123456',
          issuerId: 'issuer',
          privateKey:
              '-----BEGIN PRIVATE KEY-----\nnot-a-key\n'
              '-----END PRIVATE KEY-----',
        ),
      );

      expect(
        provider.token,
        throwsA(
          isA<StoreAuthException>()
              .having((e) => e.store, 'store', Store.appStore)
              .having((e) => e.message, 'message', contains('ABCD123456')),
        ),
      );
    });
  });

  group('AppStoreApiKey', () {
    test('repairs a PEM whose newlines were escaped in transit', () {
      // CI secret stores routinely hand the key back with literal \n.
      final key = AppStoreApiKey(
        keyId: 'ABCD123456',
        issuerId: 'issuer',
        privateKey: testPrivateKeyPem.replaceAll('\n', r'\n'),
      );

      expect(key.privateKey, testPrivateKeyPem);
      expect(AppStoreTokenProvider(key).token(), isNotEmpty);
    });

    test('repairs CRLF line endings', () {
      final key = AppStoreApiKey(
        keyId: 'ABCD123456',
        issuerId: 'issuer',
        privateKey: testPrivateKeyPem.replaceAll('\n', '\r\n'),
      );

      expect(AppStoreTokenProvider(key).token(), isNotEmpty);
    });

    test('rejects a key that is not PEM at all', () {
      expect(
        () => AppStoreApiKey(
          keyId: 'ABCD123456',
          issuerId: 'issuer',
          privateKey: 'MIGHAgEAMBMGByqGSM49AgEG',
        ),
        throwsA(isA<StoreAuthException>()),
      );
    });

    test('rejects empty IDs', () {
      expect(
        () => AppStoreApiKey(
          keyId: '',
          issuerId: 'issuer',
          privateKey: testPrivateKeyPem,
        ),
        throwsA(isA<StoreAuthException>()),
      );
      expect(
        () => AppStoreApiKey(
          keyId: 'ABCD123456',
          issuerId: '',
          privateKey: testPrivateKeyPem,
        ),
        throwsA(isA<StoreAuthException>()),
      );
    });
  });
}
