import 'dart:convert';
import 'dart:ui';

import 'package:app_lang_selector/app_lang_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const locale = Locale('en', 'US');

  setUp(rootBundle.clear);

  ByteData encode(Map<String, dynamic> json) {
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode(jsonEncode(json))),
    );
  }

  /// Serves fake JSON assets to rootBundle during the test.
  void mockAssets(Map<String, Map<String, dynamic>> assets) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      final json = assets[key];
      if (json == null) {
        return null;
      }
      return encode(json);
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });
  }

  group('PkgsAssetLoader.getPackagePath', () {
    test('builds the package asset path with a dash separator', () {
      const loader = PkgsAssetLoader(packages: []);
      expect(
        loader.getPackagePath('my_pkg', locale),
        'packages/my_pkg/assets/localizations/en-US.json',
      );
    });
  });

  group('PkgsAssetLoader.load', () {
    test('merges app locale data with package data', () async {
      mockAssets({
        'assets/localizations/en-US.json': {'app_key': 'app', 'shared': 'app'},
        'packages/pkg_a/assets/localizations/en-US.json': {
          'pkg_key': 'pkg',
          'shared': 'pkg',
        },
      });

      const loader = PkgsAssetLoader(packages: ['pkg_a']);
      final result = await loader.load('assets/localizations', locale);

      expect(result, isNotNull);
      expect(result!['app_key'], 'app');
      expect(result['pkg_key'], 'pkg');
      // Package data wins over app data on key collisions.
      expect(result['shared'], 'pkg');
    });

    test('later packages override earlier packages', () async {
      mockAssets({
        'assets/localizations/en-US.json': <String, dynamic>{},
        'packages/pkg_a/assets/localizations/en-US.json': {'key': 'a'},
        'packages/pkg_b/assets/localizations/en-US.json': {'key': 'b'},
      });

      const loader = PkgsAssetLoader(packages: ['pkg_a', 'pkg_b']);
      final result = await loader.load('assets/localizations', locale);

      expect(result!['key'], 'b');
    });

    test('loads app data only when no packages are given', () async {
      mockAssets({
        'assets/localizations/en-US.json': {'only': 'app'},
      });

      const loader = PkgsAssetLoader(packages: []);
      final result = await loader.load('assets/localizations', locale);

      expect(result, {'only': 'app'});
    });
  });
}
