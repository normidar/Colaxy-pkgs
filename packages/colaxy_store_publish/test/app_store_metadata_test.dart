import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:test/test.dart';

import 'app_store_support.dart';
import 'support.dart';

AppStoreConnectClient _client(Recorder recorder) => AppStoreConnectClient(
  apiKey: testApiKey(),
  httpClient: recorder.client,
  retryPolicy: const RetryPolicy.none(),
);

AppStorePublisher _publisher(Recorder recorder) => AppStorePublisher(
  client: _client(recorder),
  appId: '6740000000',
);

void main() {
  group('finding what is writable', () {
    test('asks the store for the editable version by filter', () async {
      final recorder = Recorder()
        ..enqueue(
          jsonApiList([
            resource('appStoreVersions', 'v1', {
              'versionString': '1.4.0',
              'appStoreState': 'PREPARE_FOR_SUBMISSION',
            }),
          ]),
        );

      final version = await _publisher(recorder).versions.editable();

      expect(version?.id, 'v1');
      expect(version?.isEditable, isTrue);
      expect(
        recorder.requests.single.url.queryParameters['filter[appStoreState]'],
        'PREPARE_FOR_SUBMISSION',
      );
    });

    test('answers null when no version is editable', () async {
      final recorder = Recorder()..enqueue(jsonApiList([]));

      expect(await _publisher(recorder).versions.editable(), isNull);
    });

    test('picks the editable app info record out of several', () async {
      // An app has one appInfo per state. Writing through the live one is
      // reported to succeed and change nothing anybody can see, which is the
      // worst failure shape there is.
      final recorder = Recorder()
        ..enqueue(
          jsonApiList([
            resource('appInfos', 'live', {'appStoreState': 'READY_FOR_SALE'}),
            resource('appInfos', 'draft', {
              'appStoreState': 'PREPARE_FOR_SUBMISSION',
            }),
          ]),
        );

      final info = await _publisher(recorder).appInfos.editable();

      expect(info?.id, 'draft');
    });

    test('filters app infos locally, because the endpoint takes none',
        () async {
      // /v1/apps/{id}/appInfos accepts no filter parameters at all, verified
      // against the 4.4.1 specification. The state cannot be pushed to the
      // server the way it can for versions.
      final recorder = Recorder()
        ..enqueue(
          jsonApiList([
            resource('appInfos', 'live', {'appStoreState': 'READY_FOR_SALE'}),
          ]),
        );

      await _publisher(recorder).appInfos.editable();

      expect(
        recorder.requests.single.url.queryParameters.keys,
        isNot(contains(startsWith('filter'))),
      );
    });

    test('answers null when no app info record is editable', () async {
      final recorder = Recorder()
        ..enqueue(
          jsonApiList([
            resource('appInfos', 'live', {'appStoreState': 'READY_FOR_SALE'}),
          ]),
        );

      expect(await _publisher(recorder).appInfos.editable(), isNull);
    });
  });

  group('the two-resource split', () {
    test('app-wide fields go to appInfoLocalizations', () {
      const listing = FastlaneIosListing(
        locale: 'ja',
        name: 'メモ帳',
        subtitle: 'すぐ書ける',
        privacyUrl: 'https://example.com/privacy',
        description: '長い説明',
      );

      final appInfo = listing.appInfoLocalization();

      expect(appInfo.name, 'メモ帳');
      expect(appInfo.subtitle, 'すぐ書ける');
      expect(appInfo.privacyPolicyUrl, 'https://example.com/privacy');
    });

    test('version fields go to appStoreVersionLocalizations', () {
      const listing = FastlaneIosListing(
        locale: 'ja',
        name: 'メモ帳',
        description: '長い説明',
        keywords: 'メモ,todo',
        releaseNotes: '不具合の修正',
        promotionalText: '宣伝',
        supportUrl: 'https://example.com/support',
      );

      final version = listing.versionLocalization();

      expect(version.description, '長い説明');
      expect(version.keywords, 'メモ,todo');
      expect(version.whatsNew, '不具合の修正');
      expect(version.promotionalText, '宣伝');
      expect(version.supportUrl, 'https://example.com/support');
    });

    test('the halves do not leak into each other', () {
      // The fastlane directory is flat and says nothing about the split, so
      // this is the only place it is enforced.
      const listing = FastlaneIosListing(
        locale: 'ja',
        name: 'メモ帳',
        description: '長い説明',
      );

      expect(listing.appInfoLocalization().isEmpty, isFalse);
      expect(listing.versionLocalization().isEmpty, isFalse);
      expect(
        listing.appInfoLocalization().toAttributes(),
        isNot(contains('description')),
      );
      expect(
        listing.versionLocalization().toAttributes(),
        isNot(contains('name')),
      );
    });
  });

  group('writing localizations', () {
    test('PATCHes an existing locale, omitting unset fields', () async {
      // This API's PATCH is a partial update, unlike Google Play's whole-object
      // listings.update — so no merge against the store is needed.
      final recorder = Recorder()
        ..enqueue(
          jsonApiList([
            resource('appStoreVersionLocalizations', 'loc-ja', {
              'locale': 'ja',
            }),
          ]),
        )
        ..enqueue(
          jsonApiOne(
            resource('appStoreVersionLocalizations', 'loc-ja', {
              'locale': 'ja',
              'description': '新しい説明',
            }),
          ),
        );
      final api = AppStoreVersionLocalizationsApi(
        client: _client(recorder),
        versionId: 'v1',
      );

      await api.update(
        const AppStoreVersionLocalization(
          locale: 'ja',
          description: '新しい説明',
        ),
      );

      final write = recorder.requests.last;
      expect(write.method, 'PATCH');
      expect(write.url.path, '/v1/appStoreVersionLocalizations/loc-ja');
      final body = jsonDecode(write.body) as Map<String, dynamic>;
      final attributes =
          (body['data'] as Map<String, dynamic>)['attributes']
              as Map<String, dynamic>;
      expect(attributes['description'], '新しい説明');
      expect(attributes, isNot(contains('keywords')));
    });

    test('POSTs a locale the version does not have yet', () async {
      final recorder = Recorder()
        ..enqueue(jsonApiList([]))
        ..enqueue(
          jsonApiOne(
            resource('appStoreVersionLocalizations', 'new', {'locale': 'de'}),
          ),
        );
      final api = AppStoreVersionLocalizationsApi(
        client: _client(recorder),
        versionId: 'v1',
      );

      await api.update(
        const AppStoreVersionLocalization(locale: 'de', description: 'Text'),
      );

      final write = recorder.requests.last;
      expect(write.method, 'POST');
      final body = jsonDecode(write.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      expect(
        (data['attributes'] as Map<String, dynamic>)['locale'],
        'de',
      );
      expect(data['relationships'], contains('appStoreVersion'));
    });

    test('refuses a localization with no locale before sending it', () {
      final recorder = Recorder();
      final api = AppStoreVersionLocalizationsApi(
        client: _client(recorder),
        versionId: 'v1',
      );

      expect(
        () => api.update(const AppStoreVersionLocalization(locale: '')),
        throwsA(isA<ArgumentError>()),
      );
      expect(recorder.requests, isEmpty);
    });

    test('app info localizations write through the record they were built '
        'for', () async {
      final recorder = Recorder()
        ..enqueue(
          jsonApiList([
            resource('appInfoLocalizations', 'ail-ja', {'locale': 'ja'}),
          ]),
        )
        ..enqueue(
          jsonApiOne(
            resource('appInfoLocalizations', 'ail-ja', {'locale': 'ja'}),
          ),
        );
      final api = AppInfoLocalizationsApi(
        client: _client(recorder),
        appInfoId: 'draft',
      );

      await api.update(
        const AppInfoLocalization(locale: 'ja', name: 'メモ帳'),
      );

      expect(recorder.requests.first.url.path, '/v1/appInfos/draft'
          '/appInfoLocalizations');
      expect(recorder.requests.last.url.path, '/v1/appInfoLocalizations'
          '/ail-ja');
    });
  });

  group('version state', () {
    test('only PREPARE_FOR_SUBMISSION is treated as writable', () {
      for (final state in AppStoreVersionState.values) {
        expect(
          state.isEditable,
          state == AppStoreVersionState.prepareForSubmission,
          reason: state.wireName,
        );
      }
    });

    test('an unknown state reads as null rather than throwing', () {
      // Apple adds states. A run that dies on one it has not seen is worse
      // than a run reporting the version is not editable.
      expect(AppStoreVersionState.byWireName('SOMETHING_NEW'), isNull);
    });

    test('AppVersionState is a different set from AppStoreVersionState', () {
      // Both are on the same resource in the specification, and conflating
      // them would silently mis-read a version's state.
      final versionStates = AppVersionState.values
          .map((state) => state.wireName)
          .toSet();
      final storeStates = AppStoreVersionState.values
          .map((state) => state.wireName)
          .toSet();

      expect(versionStates, isNot(equals(storeStates)));
      expect(versionStates, contains('READY_FOR_DISTRIBUTION'));
      expect(storeStates, isNot(contains('READY_FOR_DISTRIBUTION')));
    });
  });
}
