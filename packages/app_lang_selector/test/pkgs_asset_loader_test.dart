import 'dart:convert';
import 'dart:ui';

import 'package:app_lang_selector/app_lang_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves canned JSON for the asset paths the loader asks for.
void _stubAssets(Map<String, Map<String, String>> assets) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        final data = assets[key];
        if (data == null) return null;
        final bytes = Uint8List.fromList(utf8.encode(json.encode(data)));
        return bytes.buffer.asByteData();
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // rootBundle memoises loadString results, so a previous test's stub would
  // otherwise leak into the next one.
  setUp(rootBundle.clear);

  const locale = Locale('en', 'US');
  const appPath = 'assets/localizations';
  const packagePath =
      'packages/app_lang_selector/assets/localizations/en-US.json';

  test('merges the app and package translations', () async {
    _stubAssets({
      '$appPath/en-US.json': {'app_key': 'from app'},
      packagePath: {'app_lang_selector:select_lang': 'from package'},
    });

    const loader = PkgsAssetLoader(packages: ['app_lang_selector']);
    final merged = await loader.load(appPath, locale);

    expect(merged, {
      'app_key': 'from app',
      'app_lang_selector:select_lang': 'from package',
    });
  });

  test('the app wins when a key collides with a package key', () async {
    // The merge order used to be `{...localeData, ...packageDatas}`, which let
    // a package silently override a key the app had defined itself.
    _stubAssets({
      '$appPath/en-US.json': {'shared': 'from app'},
      packagePath: {'shared': 'from package'},
    });

    const loader = PkgsAssetLoader(packages: ['app_lang_selector']);
    final merged = await loader.load(appPath, locale);

    expect(merged?['shared'], 'from app');
  });
}
