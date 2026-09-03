import 'dart:convert';

import 'package:colaxy_store_console/colaxy_store_console.dart';
import 'package:colaxy_store_publish/colaxy_store_publish.dart';
import 'package:test/test.dart';

import 'support.dart';

PlayListingsApi _api(Recorder recorder) => PlayListingsApi(
  api: publisherApi(recorder),
  packageName: 'com.example.app',
  editId: 'edit-1',
  guard: PlayApiGuard(retryPolicy: const RetryPolicy.none()),
);

Map<String, dynamic> _listing(String language, {String? title}) => {
  'language': language,
  'title': ?title,
};

void main() {
  group('list', () {
    test('maps every listing the app has', () async {
      final recorder = Recorder()
        ..enqueue({
          'listings': [
            _listing('ja-JP', title: 'メモ'),
            _listing('en-US', title: 'Notes'),
          ],
        });

      final listings = await _api(recorder).list();

      expect(listings.map((listing) => listing.language), ['ja-JP', 'en-US']);
      expect(listings.first.title, 'メモ');
    });

    test('answers empty for an app with no listings', () async {
      final recorder = Recorder()..enqueue(const <String, dynamic>{});

      expect(await _api(recorder).list(), isEmpty);
    });
  });

  group('get', () {
    test('finds a locale through list, taking no 404 path', () async {
      final recorder = Recorder()
        ..enqueue({
          'listings': [_listing('ja-JP', title: 'メモ')],
        });

      final listing = await _api(recorder).get('ja-JP');

      expect(listing?.title, 'メモ');
      expect(recorder.trace.single, startsWith('GET'));
    });

    test('answers null for a locale with no listing', () async {
      // Never a 404: `listings.get` answers 404 for a missing locale *and*
      // for a dead edit, and treating the second as "no listing yet" would
      // report success having published nothing.
      final recorder = Recorder()
        ..enqueue({
          'listings': [_listing('en-US')],
        });

      expect(await _api(recorder).get('ja-JP'), isNull);
    });
  });

  group('update', () {
    test('writes to the locale named by the listing', () async {
      final recorder = Recorder()..enqueue(_listing('ja-JP', title: 'メモ'));

      await _api(recorder).update(
        const PlayListing(language: 'ja-JP', title: 'メモ'),
      );

      expect(recorder.requests.single.url.path, endsWith('/listings/ja-JP'));
      expect(
        jsonDecode(recorder.requests.single.body),
        containsPair('title', 'メモ'),
      );
    });

    test('omits fields left null rather than sending empty strings', () async {
      final recorder = Recorder()..enqueue(_listing('ja-JP'));

      await _api(recorder).update(
        const PlayListing(language: 'ja-JP', title: 'メモ'),
      );

      expect(
        jsonDecode(recorder.requests.single.body),
        isNot(contains('fullDescription')),
      );
    });

    test('refuses a listing with no locale before sending it', () {
      final recorder = Recorder();

      expect(
        () => _api(recorder).update(const PlayListing(language: '')),
        throwsA(isA<ArgumentError>()),
      );
      expect(recorder.requests, isEmpty);
    });
  });

  group('merge', () {
    test('keeps the store text a partial local listing does not set', () {
      const local = PlayListing(language: 'ja-JP', title: '新しいメモ');
      const store = PlayListing(
        language: 'ja-JP',
        title: '古いメモ',
        fullDescription: '長い説明',
      );

      final merged = local.merge(store);

      expect(merged.title, '新しいメモ');
      expect(merged.fullDescription, '長い説明');
    });

    test('is a no-op for a locale the store has never seen', () {
      const local = PlayListing(language: 'ja-JP', title: 'メモ');

      expect(local.merge(null), local);
    });
  });
}
