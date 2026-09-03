import 'package:colaxy_store_console/colaxy_store_console.dart';

/// A throwaway P-256 key, generated for this test suite alone.
///
/// A real EC key, so the ES256 signing path is genuinely exercised rather
/// than only its error branch. It has never been uploaded to App Store
/// Connect and grants access to nothing.
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

/// A JSON:API collection envelope holding [data].
Map<String, dynamic> jsonApiList(List<Map<String, dynamic>> data) => {
  'data': data,
};

/// A JSON:API single-resource envelope.
Map<String, dynamic> jsonApiOne(Map<String, dynamic> data) => {'data': data};

/// A JSON:API resource object.
Map<String, dynamic> resource(
  String type,
  String id,
  Map<String, dynamic> attributes,
) => {'type': type, 'id': id, 'attributes': attributes};

/// An App Store Connect error body, in the shape the client parses.
Map<String, dynamic> ascError(String code, String detail) => {
  'errors': [
    {'code': code, 'status': '409', 'title': code, 'detail': detail},
  ],
};
