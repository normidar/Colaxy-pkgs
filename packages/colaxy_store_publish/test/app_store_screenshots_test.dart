import 'dart:convert';
import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'app_store_support.dart';
import 'support.dart';

/// A reservation response with [chunks] upload operations over [size] bytes.
Map<String, dynamic> _reservation({
  required int size,
  int chunks = 1,
  String id = 'shot-1',
}) {
  final each = (size / chunks).ceil();
  return jsonApiOne(
    resource('appScreenshots', id, {
      'fileName': '01.png',
      'fileSize': size,
      'assetDeliveryState': {'state': 'AWAITING_UPLOAD'},
      'uploadOperations': [
        for (var i = 0; i < chunks; i++)
          {
            'method': 'PUT',
            'url': 'https://assets.example.com/put/$i',
            'offset': i * each,
            'length': i == chunks - 1 ? size - (i * each) : each,
            'requestHeaders': [
              {'name': 'Content-Type', 'value': 'image/png'},
            ],
          },
      ],
    }),
  );
}

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('colaxy_asc_shots');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  File shot(String name) => File(p.join(temp.path, name))
    ..writeAsBytesSync(onePixelPng);

  AppScreenshotsApi api(Recorder recorder, {Recorder? assets}) =>
      AppScreenshotsApi(
        client: AppStoreConnectClient(
          apiKey: testApiKey(),
          httpClient: recorder.client,
          retryPolicy: const RetryPolicy.none(),
        ),
        uploader: AssetUploader(
          httpClient: (assets ?? recorder).client,
          retryPolicy: const RetryPolicy.none(),
        ),
      );

  group('the three-step upload', () {
    test('reserves, sends the bytes elsewhere, then commits', () async {
      final file = shot('01.png');
      final size = file.lengthSync();
      final api1 = Recorder()
        ..enqueue(_reservation(size: size))
        ..enqueue(
          jsonApiOne(
            resource('appScreenshots', 'shot-1', {
              'assetDeliveryState': {'state': 'COMPLETE'},
            }),
          ),
        );
      final assets = Recorder()..enqueue(const <String, dynamic>{});

      await api(api1, assets: assets).upload(setId: 'set-1', file: file);

      // Reservation and commit go to Apple's API…
      expect(api1.requests.first.url.path, '/v1/appScreenshots');
      expect(api1.requests.first.method, 'POST');
      expect(api1.requests.last.method, 'PATCH');
      // …the bytes go to a different host entirely.
      expect(assets.requests.single.url.host, 'assets.example.com');
      expect(assets.requests.single.method, 'PUT');
    });

    test('the byte upload carries no Authorization header', () async {
      // Those URLs authenticate themselves; sending Apple's bearer token
      // there would be pointless and leaks it to another host.
      final file = shot('01.png');
      final api1 = Recorder()
        ..enqueue(_reservation(size: file.lengthSync()))
        ..enqueue(jsonApiOne(resource('appScreenshots', 'shot-1', {})));
      final assets = Recorder()..enqueue(const <String, dynamic>{});

      await api(api1, assets: assets).upload(setId: 'set-1', file: file);

      expect(
        assets.requests.single.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(
        assets.requests.single.headers['Content-Type'],
        'image/png',
      );
    });

    test('commits with uploaded and the MD5 of the file', () async {
      // AppScreenshot is one of the resources that requires a checksum;
      // several newer asset types do not, so it cannot be inferred.
      final file = shot('01.png');
      final api1 = Recorder()
        ..enqueue(_reservation(size: file.lengthSync()))
        ..enqueue(jsonApiOne(resource('appScreenshots', 'shot-1', {})));
      final assets = Recorder()..enqueue(const <String, dynamic>{});
      final expected = await AssetUploader.checksum(file);

      await api(api1, assets: assets).upload(setId: 'set-1', file: file);

      final body = jsonDecode(api1.requests.last.body) as Map<String, dynamic>;
      final attributes =
          (body['data'] as Map<String, dynamic>)['attributes']
              as Map<String, dynamic>;
      expect(attributes['uploaded'], isTrue);
      expect(attributes['sourceFileChecksum'], expected);
    });

    test('sends every chunk the reservation asked for', () async {
      final file = File(p.join(temp.path, 'big.png'))
        ..writeAsBytesSync(List.filled(300, 7));
      final api1 = Recorder()
        ..enqueue(_reservation(size: 300, chunks: 3))
        ..enqueue(jsonApiOne(resource('appScreenshots', 'shot-1', {})));
      final assets = Recorder()
        ..enqueue(const <String, dynamic>{})
        ..enqueue(const <String, dynamic>{})
        ..enqueue(const <String, dynamic>{});

      await api(api1, assets: assets).upload(setId: 'set-1', file: file);

      expect(assets.requests, hasLength(3));
      final sent = assets.requests.fold<int>(
        0,
        (sum, request) => sum + request.bodyBytes.length,
      );
      expect(sent, 300);
    });

    test('deletes the reservation when the upload fails', () async {
      // An uncommitted reservation shows as a grey placeholder and blocks
      // submission — worse than the upload simply having failed.
      final file = shot('01.png');
      final api1 = Recorder()
        ..enqueue(_reservation(size: file.lengthSync()))
        ..enqueue(const <String, dynamic>{});
      final assets = Recorder()
        ..enqueue(const <String, dynamic>{}, status: 403);

      await expectLater(
        api(api1, assets: assets).upload(setId: 'set-1', file: file),
        throwsA(isA<StoreApiException>()),
      );

      expect(api1.requests.last.method, 'DELETE');
      expect(api1.requests.last.url.path, '/v1/appScreenshots/shot-1');
    });

    test('refuses a reservation that described no way to upload', () async {
      final file = shot('01.png');
      final api1 = Recorder()
        ..enqueue(
          jsonApiOne(resource('appScreenshots', 'shot-1', {'fileName': 'x'})),
        )
        ..enqueue(const <String, dynamic>{});

      await expectLater(
        api(api1).upload(setId: 'set-1', file: file),
        throwsA(isA<FastlaneLayoutException>()),
      );
    });

    test('refuses a missing file before reserving anything', () {
      final recorder = Recorder();

      expect(
        () => api(recorder).upload(
          setId: 'set-1',
          file: File(p.join(temp.path, 'nope.png')),
        ),
        throwsA(isA<FastlaneLayoutException>()),
      );
      expect(recorder.requests, isEmpty);
    });
  });

  group('sets', () {
    test('reuses an existing set for the display type', () async {
      final recorder = Recorder()
        ..enqueue(
          jsonApiList([
            resource('appScreenshotSets', 'set-1', {
              'screenshotDisplayType': 'APP_IPHONE_65',
            }),
          ]),
        );

      final set = await api(recorder).ensureSet(
        localizationId: 'loc-ja',
        displayType: ScreenshotDisplayType.appIphone65,
      );

      expect(set.id, 'set-1');
      expect(recorder.requests, hasLength(1));
    });

    test('creates a set when the display type has none', () async {
      final recorder = Recorder()
        ..enqueue(jsonApiList([]))
        ..enqueue(
          jsonApiOne(
            resource('appScreenshotSets', 'new', {
              'screenshotDisplayType': 'APP_IPHONE_65',
            }),
          ),
        );

      await api(recorder).ensureSet(
        localizationId: 'loc-ja',
        displayType: ScreenshotDisplayType.appIphone65,
      );

      final body =
          jsonDecode(recorder.requests.last.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      expect(
        (data['attributes'] as Map<String, dynamic>)['screenshotDisplayType'],
        'APP_IPHONE_65',
      );
      expect(data['relationships'], contains('appStoreVersionLocalization'));
    });

    test('keeps a display type it does not recognise', () async {
      // Apple adds devices. A set this package cannot name is still a set
      // that exists, and dropping the value would make it invisible.
      final recorder = Recorder()
        ..enqueue(
          jsonApiList([
            resource('appScreenshotSets', 'set-x', {
              'screenshotDisplayType': 'APP_SOMETHING_NEW',
            }),
          ]),
        );

      final sets = await api(recorder).sets('loc-ja');

      expect(sets.single.displayType, isNull);
      expect(sets.single.rawDisplayType, 'APP_SOMETHING_NEW');
    });

    test('emptying a set deletes one screenshot at a time', () async {
      // Apple has no bulk delete and appScreenshotSets has no PATCH.
      final recorder = Recorder()
        ..enqueue(
          jsonApiList([
            resource('appScreenshots', 'a', {}),
            resource('appScreenshots', 'b', {}),
          ]),
        )
        ..enqueue(const <String, dynamic>{})
        ..enqueue(const <String, dynamic>{});

      final removed = await api(recorder).deleteAll('set-1');

      expect(removed, 2);
      expect(
        recorder.requests.where((r) => r.method == 'DELETE'),
        hasLength(2),
      );
    });
  });

  group('processing is asynchronous', () {
    test('polls until the asset is complete', () async {
      final recorder = Recorder()
        ..enqueue(
          jsonApiOne(
            resource('appScreenshots', 'shot-1', {
              'assetDeliveryState': {'state': 'UPLOAD_COMPLETE'},
            }),
          ),
        )
        ..enqueue(
          jsonApiOne(
            resource('appScreenshots', 'shot-1', {
              'assetDeliveryState': {'state': 'COMPLETE'},
            }),
          ),
        );

      final screenshot = await api(recorder).awaitProcessing(
        'shot-1',
        sleep: (_) async {},
      );

      expect(screenshot.isComplete, isTrue);
      expect(recorder.requests, hasLength(2));
    });

    test('raises what Apple objected to, after a clean upload', () async {
      // A screenshot can upload perfectly and be rejected minutes later.
      final recorder = Recorder()
        ..enqueue(
          jsonApiOne(
            resource('appScreenshots', 'shot-1', {
              'assetDeliveryState': {
                'state': 'FAILED',
                'errors': [
                  {'code': 'WRONG_SIZE', 'description': 'Bad dimensions'},
                ],
              },
            }),
          ),
        );

      await expectLater(
        api(recorder).awaitProcessing('shot-1', sleep: (_) async {}),
        throwsA(
          isA<StoreApiException>().having(
            (e) => e.message,
            'message',
            contains('Bad dimensions'),
          ),
        ),
      );
    });

    test('gives up at the deadline rather than looping forever', () async {
      final recorder = Recorder()
        ..route(
          (request) => Recorder.ok(
            jsonApiOne(
              resource('appScreenshots', 'shot-1', {
                'assetDeliveryState': {'state': 'UPLOAD_COMPLETE'},
              }),
            ),
          ),
        );

      final screenshot = await api(recorder).awaitProcessing(
        'shot-1',
        timeout: Duration.zero,
        sleep: (_) async {},
      );

      expect(screenshot.isComplete, isFalse);
      expect(recorder.requests, hasLength(1));
    });
  });
}
