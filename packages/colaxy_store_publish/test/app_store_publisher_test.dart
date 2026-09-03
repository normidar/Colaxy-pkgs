import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'app_store_support.dart';
import 'support.dart';

Directory _buildTree({
  Map<String, Map<String, String>> metadata = const {},
  Map<String, List<String>> screenshots = const {},
}) {
  final temp = Directory.systemTemp.createTempSync('colaxy_asc_pub');
  final root = p.join(temp.path, 'fastlane');
  Directory(p.join(root, 'metadata', 'android')).createSync(recursive: true);
  for (final locale in metadata.entries) {
    for (final file in locale.value.entries) {
      File(p.join(root, 'metadata', locale.key, file.key))
        ..createSync(recursive: true)
        ..writeAsStringSync(file.value);
    }
  }
  for (final locale in screenshots.entries) {
    for (final name in locale.value) {
      File(p.join(root, 'screenshots', locale.key, name))
        ..createSync(recursive: true)
        ..writeAsBytesSync(onePixelPng);
    }
  }
  return temp;
}

/// Answers every call a publish makes against an app in a healthy state.
void _serveStore(
  Recorder recorder, {
  bool versionEditable = true,
  bool appInfoEditable = true,
  Set<String> failingLocales = const {},
}) => recorder.route((request) {
  final path = request.url.path;

  if (path.endsWith('/appStoreVersions')) {
    return Recorder.ok(
      jsonApiList([
        if (versionEditable)
          resource('appStoreVersions', 'v1', {
            'versionString': '1.4.0',
            'appStoreState': 'PREPARE_FOR_SUBMISSION',
          }),
      ]),
    );
  }
  if (path.endsWith('/appInfos')) {
    return Recorder.ok(
      jsonApiList([
        resource('appInfos', 'live', {'appStoreState': 'READY_FOR_SALE'}),
        if (appInfoEditable)
          resource('appInfos', 'draft', {
            'appStoreState': 'PREPARE_FOR_SUBMISSION',
          }),
      ]),
    );
  }
  if (path.endsWith('/appStoreVersionLocalizations')) {
    return Recorder.ok(
      jsonApiList([
        resource('appStoreVersionLocalizations', 'loc-ja', {'locale': 'ja'}),
        resource('appStoreVersionLocalizations', 'loc-en', {
          'locale': 'en-US',
        }),
      ]),
    );
  }
  if (path.endsWith('/appInfoLocalizations')) {
    return Recorder.ok(
      jsonApiList([
        resource('appInfoLocalizations', 'ail-ja', {'locale': 'ja'}),
        resource('appInfoLocalizations', 'ail-en', {'locale': 'en-US'}),
      ]),
    );
  }
  if (path.contains('/appInfoLocalizations/')) {
    final failing = failingLocales.any(
      (locale) => path.endsWith('ail-${locale.split('-').first}'),
    );
    if (failing) {
      return Recorder.error(ascError('STATE_ERROR', 'locked'), status: 409);
    }
    return Recorder.ok(jsonApiOne(resource('appInfoLocalizations', 'x', {})));
  }
  if (path.contains('/appStoreVersionLocalizations/')) {
    return Recorder.ok(
      jsonApiOne(resource('appStoreVersionLocalizations', 'x', {})),
    );
  }
  // The list and the create differ only by method: a version localization's
  // sets are at `…/appScreenshotSets`, and creating one POSTs to
  // `/v1/appScreenshotSets`.
  if (path.endsWith('/appScreenshotSets')) {
    if (request.method == 'POST') {
      return Recorder.ok(
        jsonApiOne(
          resource('appScreenshotSets', 'set-1', {
            'screenshotDisplayType': 'APP_IPHONE_65',
          }),
        ),
      );
    }
    return Recorder.ok(jsonApiList([]));
  }
  if (path == '/v1/appScreenshots') {
    return Recorder.ok(
      jsonApiOne(
        resource('appScreenshots', 'shot-1', {
          'fileSize': onePixelPng.length,
          'assetDeliveryState': {'state': 'AWAITING_UPLOAD'},
          'uploadOperations': [
            {
              'method': 'PUT',
              'url': 'https://assets.example.com/put/0',
              'offset': 0,
              'length': onePixelPng.length,
              'requestHeaders': <dynamic>[],
            },
          ],
        }),
      ),
    );
  }
  if (path.startsWith('/v1/appScreenshots/')) {
    return Recorder.ok(
      jsonApiOne(
        resource('appScreenshots', 'shot-1', {
          'assetDeliveryState': {'state': 'COMPLETE'},
        }),
      ),
    );
  }
  return Recorder.ok(const <String, dynamic>{});
});

AppStorePublisher _publisher(Recorder api, http.Client assets) =>
    AppStorePublisher(
      client: AppStoreConnectClient(
        apiKey: testApiKey(),
        httpClient: api.client,
        retryPolicy: const RetryPolicy.none(),
      ),
      appId: '6740000000',
      uploader: AssetUploader(
        httpClient: assets,
        retryPolicy: const RetryPolicy.none(),
      ),
    );

void main() {
  late Directory temp;

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  AppStoreMetadataPublisher publisher(
    Recorder api,
    Recorder assets, {
    AppStorePublishOptions options = const AppStorePublishOptions(),
  }) => AppStoreMetadataPublisher(
    publisher: _publisher(api, assets.client),
    metadata: FastlaneIosMetadata.forProject(temp.path),
    options: options,
  );

  test('writes both halves of the metadata, to different records', () async {
    temp = _buildTree(
      metadata: {
        'ja': {'name.txt': 'メモ帳', 'description.txt': '長い説明'},
      },
    );
    final api = Recorder();
    final assets = Recorder();
    _serveStore(api);

    final report = await publisher(
      api,
      assets,
      options: const AppStorePublishOptions(publishScreenshots: false),
    ).publish();

    expect(report.appInfoLocales, ['ja']);
    expect(report.versionLocales, ['ja']);
    // The app-wide write goes through the draft appInfo, not the live one.
    expect(
      api.trace.any((line) => line.contains('/v1/appInfos/draft/')),
      isTrue,
    );
  });

  test('stops rather than writing app info through a locked record',
      () async {
    // Writing through a record in another state is reported to succeed and
    // change nothing anybody can see.
    temp = _buildTree(
      metadata: {
        'ja': {'name.txt': 'メモ帳'},
      },
    );
    final api = Recorder();
    _serveStore(api, appInfoEditable: false);

    await expectLater(
      publisher(api, Recorder()).publish(),
      throwsA(
        isA<FastlaneLayoutException>().having(
          (e) => e.message,
          'message',
          contains('changes nothing'),
        ),
      ),
    );
  });

  test('stops when no version is in PREPARE_FOR_SUBMISSION', () async {
    temp = _buildTree(
      metadata: {
        'ja': {'description.txt': '長い説明'},
      },
    );
    final api = Recorder();
    _serveStore(api, versionEditable: false);

    await expectLater(
      publisher(api, Recorder()).publish(),
      throwsA(
        isA<FastlaneLayoutException>().having(
          (e) => e.message,
          'message',
          contains('release decision'),
        ),
      ),
    );
  });

  test('a failing locale does not abort the rest of the run', () async {
    // With no transaction to roll back, stopping early leaves the store just
    // as half-updated as continuing, minus the locales that would have
    // worked.
    temp = _buildTree(
      metadata: {
        'ja': {'name.txt': 'メモ帳'},
        'en-US': {'name.txt': 'Notes'},
      },
    );
    final api = Recorder();
    _serveStore(api, failingLocales: {'ja'});

    final report = await publisher(
      api,
      Recorder(),
      options: const AppStorePublishOptions(publishScreenshots: false),
    ).publish();

    expect(report.failedLocales.keys, ['ja']);
    expect(report.appInfoLocales, ['en-US']);
    expect(report.hasFailures, isTrue);
  });

  test('uploads screenshots through the version localization', () async {
    temp = _buildTree(
      metadata: {
        'ja': {'description.txt': '長い説明'},
      },
      screenshots: {
        'ja': ['1_iphone65_1.welcome.png'],
      },
    );
    final api = Recorder();
    final assets = Recorder();
    _serveStore(api);

    final report = await publisher(
      api,
      assets,
      options: const AppStorePublishOptions(publishAppInfo: false),
    ).publish();

    expect(report.screenshotCount, 1);
    expect(assets.requests, hasLength(1));
    expect(assets.requests.single.url.host, 'assets.example.com');
  });

  test('reports screenshots it could not place', () async {
    temp = _buildTree(
      metadata: {
        'ja': {'description.txt': '長い説明'},
      },
      screenshots: {
        'ja': ['1_pixelfold_1.png'],
      },
    );
    final api = Recorder();
    _serveStore(api);

    final report = await publisher(
      api,
      Recorder(),
      options: const AppStorePublishOptions(publishAppInfo: false),
    ).publish();

    expect(report.unmappedScreenshots, hasLength(1));
    expect(report.screenshotCount, 0);
  });

  test('deletes nothing unless replacement is asked for', () async {
    temp = _buildTree(
      metadata: {
        'ja': {'description.txt': '長い説明'},
      },
      screenshots: {
        'ja': ['1_iphone65_1.png'],
      },
    );
    final api = Recorder();
    _serveStore(api);

    final report = await publisher(
      api,
      Recorder(),
      options: const AppStorePublishOptions(publishAppInfo: false),
    ).publish();

    expect(report.deletedCount, 0);
    expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);
  });

  test('skips a locale asked for and not present', () async {
    temp = _buildTree(
      metadata: {
        'ja': {'name.txt': 'メモ帳'},
      },
    );
    final api = Recorder();
    _serveStore(api);

    final report = await publisher(
      api,
      Recorder(),
      options: const AppStorePublishOptions(
        locales: {'ja', 'de-DE'},
        publishScreenshots: false,
      ),
    ).publish();

    expect(report.skippedLocales, ['de-DE']);
    expect(report.appInfoLocales, ['ja']);
  });

  test('a run that writes nothing reports itself as empty', () async {
    temp = _buildTree(metadata: {'ja': {}});
    Directory(p.join(temp.path, 'fastlane', 'metadata', 'ja'))
        .createSync(recursive: true);
    final api = Recorder();
    _serveStore(api);

    final report = await publisher(api, Recorder()).publish();

    expect(report.isEmpty, isTrue);
    expect(report.skippedLocales, ['ja']);
  });
}
