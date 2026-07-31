import 'package:colaxy_tutorial/colaxy_tutorial.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('saveShowedIds', () {
    test('marks each id as shown', () async {
      await TutorialTool.saveShowedIds(['a', 'b']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('$packageName:a'), isTrue);
      expect(prefs.getBool('$packageName:b'), isTrue);
      expect(
        prefs.getStringList('$packageName:showed_ids'),
        containsAll(['a', 'b']),
      );
    });

    test('accumulates ids across calls without duplicating them', () async {
      await TutorialTool.saveShowedIds(['a']);
      await TutorialTool.saveShowedIds(['a', 'b']);

      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('$packageName:showed_ids')!;
      expect(ids..sort(), ['a', 'b']);
    });
  });

  group('resetTutorial', () {
    test('clears the shown flags and the id list', () async {
      await TutorialTool.saveShowedIds(['a', 'b']);
      await TutorialTool.resetTutorial();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('$packageName:a'), isNull);
      expect(prefs.getBool('$packageName:b'), isNull);
      expect(prefs.getStringList('$packageName:showed_ids'), isNull);
    });

    test('is a no-op when nothing was ever shown', () async {
      await TutorialTool.resetTutorial();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('$packageName:showed_ids'), isNull);
    });
  });

  group('VersionRecorder', () {
    test('reports no match before anything is recorded', () async {
      expect(
        await VersionRecorder.isRecordedVersionOr(checker: (_) => true),
        isFalse,
      );
      // `every` on an empty list is vacuously true.
      expect(
        await VersionRecorder.isRecordedVersionAnd(checker: (_) => false),
        isTrue,
      );
    });

    test('matches recorded build numbers', () async {
      SharedPreferences.setMockInitialValues({
        VersionRecorder.key: ['1', '2'],
      });

      expect(
        await VersionRecorder.isRecordedVersionOr(checker: (v) => v == '2'),
        isTrue,
      );
      expect(
        await VersionRecorder.isRecordedVersionAnd(checker: (v) => v == '2'),
        isFalse,
      );
    });
  });
}
