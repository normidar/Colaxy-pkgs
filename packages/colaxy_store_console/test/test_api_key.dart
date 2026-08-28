import 'package:colaxy_store_console/colaxy_store_console.dart';

/// A throwaway P-256 key, generated for this test suite alone.
///
/// It is a real EC key so the ES256 signing path is genuinely exercised — a
/// fake string would only ever reach the PEM parser's error branch. It has
/// never been uploaded to App Store Connect and grants access to nothing.
const testPrivateKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgSzYQeOyB13qwlaFr
4GP6aUGgN9JPCcbz1nMP14YX8RWhRANCAARBAvshEt3VLg6KPttwPhFY7/IqokKz
xSi8D2fEMU3FRlfYR4Q3l+Gr6+NYo1ekBOm7QwVEtvpQhNxa0YM95PSI
-----END PRIVATE KEY-----''';

/// An [AppStoreApiKey] backed by [testPrivateKeyPem].
AppStoreApiKey testApiKey() => AppStoreApiKey(
  keyId: 'ABCD123456',
  issuerId: '69a6de70-0000-0000-0000-1f2c3d4e5f60',
  privateKey: testPrivateKeyPem,
);
