import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:test/test.dart';

import 'app_store_support.dart';
import 'support.dart';

AppStoreVersionsApi _api(Recorder recorder) => AppStoreVersionsApi(
  client: AppStoreConnectClient(
    apiKey: testApiKey(),
    httpClient: recorder.client,
    retryPolicy: const RetryPolicy.none(),
  ),
  appId: '6740000000',
);

void main() {
  test(
    "create() posts a version resource and returns Apple's response",
    () async {
      final recorder = Recorder()
        ..enqueue(
          jsonApiOne(
            resource('appStoreVersions', 'v2', {
              'versionString': '1.2.6',
              'platform': 'IOS',
              'appStoreState': 'PREPARE_FOR_SUBMISSION',
            }),
          ),
        );

      final created = await _api(recorder).create(versionString: '1.2.6');

      expect(created.id, 'v2');
      expect(created.versionString, '1.2.6');
      expect(created.isEditable, isTrue);

      final request = recorder.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/v1/appStoreVersions');
    },
  );

  test('create() defaults to IOS but honours another platform', () async {
    final recorder = Recorder()
      ..enqueue(
        jsonApiOne(
          resource('appStoreVersions', 'v3', {
            'versionString': '2.0.0',
            'platform': 'MAC_OS',
          }),
        ),
      );

    await _api(recorder).create(versionString: '2.0.0', platform: 'MAC_OS');

    final body =
        jsonDecode(recorder.requests.single.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    expect(data['type'], 'appStoreVersions');

    final attributes = data['attributes'] as Map<String, dynamic>;
    expect(attributes['platform'], 'MAC_OS');
    expect(attributes['versionString'], '2.0.0');

    final relationships = data['relationships'] as Map<String, dynamic>;
    final app = relationships['app'] as Map<String, dynamic>;
    expect((app['data'] as Map<String, dynamic>)['type'], 'apps');
    expect((app['data'] as Map<String, dynamic>)['id'], '6740000000');
  });
}
