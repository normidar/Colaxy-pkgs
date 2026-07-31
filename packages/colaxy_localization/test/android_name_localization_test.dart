import 'dart:io';

import 'package:colaxy_localization/colaxy_localization.dart';
import 'package:test/test.dart';

late Directory _root;

String get _resFolder => '${_root.path}/android/app/src/main/res';

void _writeStrings(String relative, String content) {
  File('$_resFolder/$relative')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}

String _readStrings(String relative) =>
    File('$_resFolder/$relative').readAsStringSync();

void main() {
  setUp(() {
    _root = Directory.systemTemp.createTempSync('android_name_test');
  });
  tearDown(() => _root.deleteSync(recursive: true));

  AndroidNameLocalization localizer() =>
      AndroidNameLocalization(rootPath: _root.path);

  group('fitLocale', () {
    test('creates strings.xml when there is none', () {
      localizer().fitLocale(appName: 'Demo');

      expect(_readStrings('values/strings.xml'), contains('>Demo<'));
    });

    test('keeps the other string resources in the file', () {
      // The whole file used to be overwritten, silently deleting everything
      // the app author had put in it.
      _writeStrings('values/strings.xml', '''
<resources>
    <string name="app_name">Old</string>
    <string name="facebook_app_id">1234567890</string>
    <string name="custom_label">Keep me</string>
</resources>
''');

      localizer().fitLocale(appName: 'New');

      final result = _readStrings('values/strings.xml');
      expect(result, contains('>New<'));
      expect(result, contains('facebook_app_id'));
      expect(result, contains('Keep me'));
      expect(result, isNot(contains('>Old<')));
    });

    test('adds app_name to a file that does not have it yet', () {
      _writeStrings('values/strings.xml', '''
<resources>
    <string name="other">Other</string>
</resources>
''');

      localizer().fitLocale(appName: 'Demo');

      final result = _readStrings('values/strings.xml');
      expect(result, contains('>Demo<'));
      expect(result, contains('>Other<'));
    });

    test('escapes characters that are special in XML', () {
      localizer().fitLocale(appName: 'Tom & Jerry <fun>');

      final result = _readStrings('values/strings.xml');
      expect(result, contains('&amp;'));
      expect(result, isNot(contains('<fun>')));
    });

    test('writes a locale into its values-<qualifier> folder', () {
      localizer().fitLocale(appName: 'デモ', locale: 'ja-JP');

      expect(_readStrings('values-ja/strings.xml'), contains('>デモ<'));
    });

    test('names the unmapped locale instead of a null crash', () {
      expect(
        () => localizer().fitLocale(appName: 'Demo', locale: 'xx-YY'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('xx-YY'), contains('ja-JP')),
          ),
        ),
      );
    });
  });

  group('updateManifestAppName', () {
    void writeManifest(String content) {
      File('${_root.path}/android/app/src/main/AndroidManifest.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    String readManifest() => File(
      '${_root.path}/android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    test('points android:label at the string resource', () {
      writeManifest(r'''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="Hardcoded" android:name="${applicationName}">
    </application>
</manifest>
''');

      localizer().updateManifestAppName();

      expect(readManifest(), contains('android:label="@string/app_name"'));
    });

    test('keeps the comments the app author wrote', () {
      // Every comment in the document used to be stripped.
      writeManifest('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Required for the deep-link handler, do not remove -->
    <application android:label="Hardcoded">
    </application>
</manifest>
''');

      localizer().updateManifestAppName();

      expect(readManifest(), contains('do not remove'));
    });

    test('reports a missing manifest by path', () {
      expect(
        localizer().updateManifestAppName,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('AndroidManifest.xml'),
          ),
        ),
      );
    });
  });
}
