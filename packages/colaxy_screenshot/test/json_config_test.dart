import 'dart:convert';
import 'dart:io';

import 'package:colaxy_screenshot/colaxy_screenshot.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockConfigAsset(Map<String, String> config) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      if (key == 'assets/config.json') {
        return ByteData.sublistView(
          Uint8List.fromList(utf8.encode(jsonEncode(config))),
        );
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });
  }

  setUp(rootBundle.clear);

  group('getJsonConfig', () {
    test('parses the bundled config as a string map', () async {
      mockConfigAsset({'launch_mode': 'screenshot', 'app_path': '/tmp/app'});

      final config = await getJsonConfig();

      expect(config, {'launch_mode': 'screenshot', 'app_path': '/tmp/app'});
    });
  });

  group('checkScreenshotRunable', () {
    test(
      'is false when not running on macOS',
      () async {
        mockConfigAsset({'launch_mode': 'screenshot', 'app_path': '/tmp/app'});

        // On any platform other than macOS the check must fail regardless of
        // the config content.
        if (!Platform.isMacOS) {
          expect(await checkScreenshotRunable(), isFalse);
        }
      },
      skip: Platform.isMacOS ? 'behavior differs on macOS hosts' : null,
    );
  });
}
