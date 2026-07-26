import 'package:colaxy_tutorial/colaxy_tutorial.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Test App',
      packageName: 'com.example.test',
      version: '1.0.0',
      buildNumber: '7',
      buildSignature: '',
    );
  });

  group('VersionRecorder.recordVersion', () {
    test('records the current build number', () async {
      await VersionRecorder.recordVersion();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(VersionRecorder.key), ['7']);
    });

    test('does not record the same build number twice', () async {
      await VersionRecorder.recordVersion();
      await VersionRecorder.recordVersion();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(VersionRecorder.key), ['7']);
    });

    test('appends new build numbers to existing records', () async {
      SharedPreferences.setMockInitialValues({
        VersionRecorder.key: ['5', '6'],
      });

      await VersionRecorder.recordVersion();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(VersionRecorder.key), ['5', '6', '7']);
    });
  });

  group('VersionRecorder.isRecordedVersionAnd', () {
    test('is true when every recorded version matches', () async {
      SharedPreferences.setMockInitialValues({
        VersionRecorder.key: ['5', '6'],
      });

      expect(
        await VersionRecorder.isRecordedVersionAnd(
          checker: (version) => int.parse(version) < 10,
        ),
        isTrue,
      );
    });

    test('is false when one recorded version does not match', () async {
      SharedPreferences.setMockInitialValues({
        VersionRecorder.key: ['5', '20'],
      });

      expect(
        await VersionRecorder.isRecordedVersionAnd(
          checker: (version) => int.parse(version) < 10,
        ),
        isFalse,
      );
    });

    test('is true for an empty record list', () async {
      expect(
        await VersionRecorder.isRecordedVersionAnd(checker: (_) => false),
        isTrue,
      );
    });
  });

  group('VersionRecorder.isRecordedVersionOr', () {
    test('is true when any recorded version matches', () async {
      SharedPreferences.setMockInitialValues({
        VersionRecorder.key: ['5', '20'],
      });

      expect(
        await VersionRecorder.isRecordedVersionOr(
          checker: (version) => version == '20',
        ),
        isTrue,
      );
    });

    test('is false when no recorded version matches', () async {
      SharedPreferences.setMockInitialValues({
        VersionRecorder.key: ['5', '6'],
      });

      expect(
        await VersionRecorder.isRecordedVersionOr(
          checker: (version) => version == '20',
        ),
        isFalse,
      );
    });

    test('is false for an empty record list', () async {
      expect(
        await VersionRecorder.isRecordedVersionOr(checker: (_) => true),
        isFalse,
      );
    });
  });
}
