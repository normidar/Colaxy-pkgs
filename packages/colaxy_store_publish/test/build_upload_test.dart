import 'dart:convert';
import 'dart:io';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'app_store_support.dart';
import 'support.dart';

/// A build upload resource in [state].
Map<String, dynamic> _upload(
  String state, {
  List<Map<String, String>> errors = const [],
}) => jsonApiOne(
  resource('buildUploads', 'bu-1', {
    'cfBundleVersion': '412',
    'cfBundleShortVersionString': '1.4.0',
    'platform': 'IOS',
    'state': {'state': state, 'errors': errors},
  }),
);

/// A reserved file with one upload operation over [size] bytes.
Map<String, dynamic> _reservedFile(int size) => jsonApiOne(
  resource('buildUploadFiles', 'buf-1', {
    'fileName': 'App.ipa',
    'fileSize': size,
    'assetType': 'ASSET',
    'uti': 'com.apple.ipa',
    'assetDeliveryState': {'state': 'AWAITING_UPLOAD'},
    'uploadOperations': [
      {
        'method': 'PUT',
        'url': 'https://assets.example.com/put/0',
        'offset': 0,
        'length': size,
        'requestHeaders': <dynamic>[],
      },
    ],
  }),
);

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('colaxy_build_upload');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  File archive(String name, {int size = 64}) =>
      File(p.join(temp.path, name))..writeAsBytesSync(List.filled(size, 3));

  AppStorePublisher publisher(Recorder api, Recorder assets) =>
      AppStorePublisher(
        client: AppStoreConnectClient(
          apiKey: testApiKey(),
          httpClient: api.client,
          retryPolicy: const RetryPolicy.none(),
        ),
        appId: '6740000000',
        uploader: AssetUploader(
          httpClient: assets.client,
          retryPolicy: const RetryPolicy.none(),
        ),
      );

  group('the four-step delivery', () {
    test('declares, reserves, sends elsewhere, commits, then polls', () async {
      final file = archive('App.ipa');
      final api = Recorder()
        ..enqueue(_upload('AWAITING_UPLOAD'))
        ..enqueue(_reservedFile(file.lengthSync()))
        ..enqueue(jsonApiOne(resource('buildUploadFiles', 'buf-1', {})))
        ..enqueue(_upload('COMPLETE'));
      final assets = Recorder()..enqueue(const <String, dynamic>{});

      final upload = await publisher(api, assets).buildUploads.upload(
        file: file,
        cfBundleVersion: '412',
        cfBundleShortVersionString: '1.4.0',
        sleep: (_) async {},
      );

      expect(upload.isComplete, isTrue);
      expect(api.trace, [
        'POST /v1/buildUploads',
        'POST /v1/buildUploadFiles',
        'PATCH /v1/buildUploadFiles/buf-1',
        'GET /v1/buildUploads/bu-1',
      ]);
      // The bytes never touch the API — every request body in the spec is
      // JSON, so the archive goes to Apple's asset host.
      expect(assets.requests.single.url.host, 'assets.example.com');
    });

    test('declares the version rather than reading it from the file',
        () async {
      // Google Play reads the version code out of the bundle. Apple takes
      // this on trust, so asserting it wrongly is not caught by the archive.
      final file = archive('App.ipa');
      final api = Recorder()
        ..enqueue(_upload('AWAITING_UPLOAD'))
        ..enqueue(_reservedFile(file.lengthSync()))
        ..enqueue(jsonApiOne(resource('buildUploadFiles', 'buf-1', {})))
        ..enqueue(_upload('COMPLETE'));

      await publisher(api, Recorder()..enqueue(const <String, dynamic>{}))
          .buildUploads
          .upload(
            file: file,
            cfBundleVersion: '412',
            cfBundleShortVersionString: '1.4.0',
            sleep: (_) async {},
          );

      final body = jsonDecode(api.requests.first.body) as Map<String, dynamic>;
      final attributes = (body['data'] as Map<String, dynamic>)['attributes']
          as Map<String, dynamic>;
      expect(attributes['cfBundleVersion'], '412');
      expect(attributes['cfBundleShortVersionString'], '1.4.0');
      expect(attributes['platform'], 'IOS');
    });

    test('reserves with the ASSET slot and the ipa type identifier',
        () async {
      // Both are enums in the specification, not free strings.
      final file = archive('App.ipa');
      final api = Recorder()
        ..enqueue(_upload('AWAITING_UPLOAD'))
        ..enqueue(_reservedFile(file.lengthSync()))
        ..enqueue(jsonApiOne(resource('buildUploadFiles', 'buf-1', {})))
        ..enqueue(_upload('COMPLETE'));

      await publisher(api, Recorder()..enqueue(const <String, dynamic>{}))
          .buildUploads
          .upload(
            file: file,
            cfBundleVersion: '412',
            cfBundleShortVersionString: '1.4.0',
            sleep: (_) async {},
          );

      final body = jsonDecode(api.requests[1].body) as Map<String, dynamic>;
      final attributes = (body['data'] as Map<String, dynamic>)['attributes']
          as Map<String, dynamic>;
      expect(attributes['assetType'], 'ASSET');
      expect(attributes['uti'], 'com.apple.ipa');
    });

    test('commits with a Checksums object naming the algorithm', () async {
      // A screenshot commits with a bare sourceFileChecksum string; a build
      // upload names the algorithm. Confusing the two fails obscurely.
      final file = archive('App.ipa');
      final api = Recorder()
        ..enqueue(_upload('AWAITING_UPLOAD'))
        ..enqueue(_reservedFile(file.lengthSync()))
        ..enqueue(jsonApiOne(resource('buildUploadFiles', 'buf-1', {})))
        ..enqueue(_upload('COMPLETE'));
      final expected = await AssetUploader.checksum(
        file,
        algorithm: ChecksumAlgorithm.sha256,
      );

      await publisher(api, Recorder()..enqueue(const <String, dynamic>{}))
          .buildUploads
          .upload(
            file: file,
            cfBundleVersion: '412',
            cfBundleShortVersionString: '1.4.0',
            sleep: (_) async {},
          );

      final body = jsonDecode(api.requests[2].body) as Map<String, dynamic>;
      final attributes = (body['data'] as Map<String, dynamic>)['attributes']
          as Map<String, dynamic>;
      expect(attributes['uploaded'], isTrue);
      final checksums = attributes['sourceFileChecksums']
          as Map<String, dynamic>;
      final fileHash = checksums['file'] as Map<String, dynamic>;
      expect(fileHash['algorithm'], 'SHA_256');
      expect(fileHash['hash'], expected);
    });

    test('abandons the upload when the transfer fails', () async {
      // An upload left in AWAITING_UPLOAD is not a build, just clutter that
      // nothing else clears.
      final file = archive('App.ipa');
      final api = Recorder()
        ..enqueue(_upload('AWAITING_UPLOAD'))
        ..enqueue(_reservedFile(file.lengthSync()))
        ..enqueue(const <String, dynamic>{});
      final assets = Recorder()
        ..enqueue(const <String, dynamic>{}, status: 403);

      await expectLater(
        publisher(api, assets).buildUploads.upload(
          file: file,
          cfBundleVersion: '412',
          cfBundleShortVersionString: '1.4.0',
        ),
        throwsA(isA<StoreApiException>()),
      );

      expect(api.trace.last, 'DELETE /v1/buildUploads/bu-1');
    });

    test('raises what Apple objected to after the bytes arrived', () async {
      final file = archive('App.ipa');
      final api = Recorder()
        ..enqueue(_upload('AWAITING_UPLOAD'))
        ..enqueue(_reservedFile(file.lengthSync()))
        ..enqueue(jsonApiOne(resource('buildUploadFiles', 'buf-1', {})))
        ..enqueue(
          _upload(
            'FAILED',
            errors: [
              {'code': 'BAD_SIGNATURE', 'description': 'Invalid signature'},
            ],
          ),
        );

      await expectLater(
        publisher(api, Recorder()..enqueue(const <String, dynamic>{}))
            .buildUploads
            .upload(
              file: file,
              cfBundleVersion: '412',
              cfBundleShortVersionString: '1.4.0',
              sleep: (_) async {},
            ),
        throwsA(
          isA<StoreApiException>().having(
            (e) => e.message,
            'message',
            contains('Invalid signature'),
          ),
        ),
      );
    });

    test('gives up polling at the deadline rather than looping', () async {
      final file = archive('App.ipa');
      final api = Recorder()
        ..enqueue(_upload('AWAITING_UPLOAD'))
        ..enqueue(_reservedFile(file.lengthSync()))
        ..enqueue(jsonApiOne(resource('buildUploadFiles', 'buf-1', {})))
        ..route((request) {
          if (request.url.path == '/v1/buildUploads/bu-1') {
            return Recorder.ok(_upload('PROCESSING'));
          }
          return null;
        });

      final upload = await publisher(
        api,
        Recorder()..enqueue(const <String, dynamic>{}),
      ).buildUploads.upload(
        file: file,
        cfBundleVersion: '412',
        cfBundleShortVersionString: '1.4.0',
        timeout: Duration.zero,
        sleep: (_) async {},
      );

      expect(upload.isComplete, isFalse);
    });
  });

  group('what it refuses', () {
    test('a missing file, before declaring anything', () {
      final api = Recorder();

      expect(
        () => publisher(api, Recorder()).buildUploads.upload(
          file: File(p.join(temp.path, 'nope.ipa')),
          cfBundleVersion: '412',
          cfBundleShortVersionString: '1.4.0',
        ),
        throwsA(isA<FastlaneLayoutException>()),
      );
      expect(api.requests, isEmpty);
    });

    test('an aab, which belongs to the other store', () {
      final api = Recorder();

      expect(
        () => publisher(api, Recorder()).buildUploads.upload(
          file: archive('app.aab'),
          cfBundleVersion: '412',
          cfBundleShortVersionString: '1.4.0',
        ),
        throwsA(isA<FastlaneLayoutException>()),
      );
      expect(api.requests, isEmpty);
    });
  });

  group('type identifiers', () {
    test('maps the suffixes Apple accepts', () {
      expect(BuildUploadUti.byExtension('.ipa'), BuildUploadUti.ipa);
      expect(BuildUploadUti.byExtension('.PKG'), BuildUploadUti.pkg);
      expect(BuildUploadUti.byExtension('.zip'), BuildUploadUti.zipArchive);
    });

    test('answers null for a suffix that is not one of the five', () {
      // uti is an enum in the specification, so an unlisted kind cannot be
      // uploaded at all — guessing one would fail somewhere unrelated.
      expect(BuildUploadUti.byExtension('.aab'), isNull);
    });

    test('the three asset slots match the three relationships', () {
      expect(
        BuildUploadAssetType.values.map((t) => t.wireName),
        ['ASSET', 'ASSET_DESCRIPTION', 'ASSET_SPI'],
      );
    });
  });

  group('checksums', () {
    test('md5 and sha256 differ, and both are available', () async {
      final file = archive('App.ipa');

      final digestMd5 = await AssetUploader.checksum(file);
      final digestSha = await AssetUploader.checksum(
        file,
        algorithm: ChecksumAlgorithm.sha256,
      );

      expect(digestMd5, isNot(digestSha));
      expect(digestMd5.length, 32);
      expect(digestSha.length, 64);
    });
  });
}
