import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_helper/riverpod_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('PrefsStringPod', () {
    test('build returns null when no value is stored', () async {
      expect(await container.read(prefsStringPodProvider('key').future), null);
    });

    test('setValue stores and exposes the value', () async {
      final notifier = container.read(prefsStringPodProvider('key').notifier);
      await notifier.setValue('hello');
      expect(
        await container.read(prefsStringPodProvider('key').future),
        'hello',
      );
    });

    test('removeValue clears the value', () async {
      final notifier = container.read(prefsStringPodProvider('key').notifier);
      await notifier.setValue('hello');
      await notifier.removeValue();
      expect(await container.read(prefsStringPodProvider('key').future), null);
    });

    test('different keys are independent', () async {
      await container
          .read(prefsStringPodProvider('a').notifier)
          .setValue('valueA');
      expect(await container.read(prefsStringPodProvider('b').future), null);
      expect(
        await container.read(prefsStringPodProvider('a').future),
        'valueA',
      );
    });
  });

  group('PrefsBoolPod', () {
    test('build reads a pre-existing value', () async {
      SharedPreferences.setMockInitialValues({'flag': true});
      expect(await container.read(prefsBoolPodProvider('flag').future), true);
    });

    test('setValue stores the value', () async {
      await container
          .read(prefsBoolPodProvider('flag').notifier)
          .setValue(true);
      expect(await container.read(prefsBoolPodProvider('flag').future), true);
    });
  });

  group('PrefsIntPod', () {
    test('setValue and removeValue round-trip', () async {
      final notifier = container.read(prefsIntPodProvider('n').notifier);
      await notifier.setValue(5);
      expect(await container.read(prefsIntPodProvider('n').future), 5);
      await notifier.removeValue();
      expect(await container.read(prefsIntPodProvider('n').future), null);
    });
  });

  group('PrefsDoublePod', () {
    test('setValue stores the value', () async {
      await container.read(prefsDoublePodProvider('d').notifier).setValue(1.5);
      expect(await container.read(prefsDoublePodProvider('d').future), 1.5);
    });
  });

  group('PrefsStrLstPod', () {
    test('setValue stores the list', () async {
      await container
          .read(prefsStrLstPodProvider('l').notifier)
          .setValue(['x', 'y']);
      expect(
        await container.read(prefsStrLstPodProvider('l').future),
        ['x', 'y'],
      );
    });
  });

  group('PrefsMapPod', () {
    test('build returns null when no value is stored', () async {
      expect(await container.read(prefsMapPodProvider('m').future), null);
    });

    test('setValue serializes and build deserializes the map', () async {
      final map = {
        'name': 'colaxy',
        'count': 3,
        'nested': {'a': true},
      };
      await container.read(prefsMapPodProvider('m').notifier).setValue(map);
      expect(await container.read(prefsMapPodProvider('m').future), map);
    });

    test('removeValue clears the value', () async {
      final notifier = container.read(prefsMapPodProvider('m').notifier);
      await notifier.setValue({'a': 1});
      await notifier.removeValue();
      expect(await container.read(prefsMapPodProvider('m').future), null);
    });
  });

  group('alive pods', () {
    test('PrefsAliveStringPod setValue stores the value', () async {
      await container
          .read(prefsAliveStringPodProvider('k').notifier)
          .setValue('v');
      expect(
        await container.read(prefsAliveStringPodProvider('k').future),
        'v',
      );
    });

    test('PrefsAliveIntPod setValue stores the value', () async {
      await container.read(prefsAliveIntPodProvider('k').notifier).setValue(9);
      expect(await container.read(prefsAliveIntPodProvider('k').future), 9);
    });

    test('PrefsAliveBoolPod setValue stores the value', () async {
      await container
          .read(prefsAliveBoolPodProvider('k').notifier)
          .setValue(true);
      expect(await container.read(prefsAliveBoolPodProvider('k').future), true);
    });

    test('PrefsAliveDoublePod setValue stores the value', () async {
      await container
          .read(prefsAliveDoublePodProvider('k').notifier)
          .setValue(2.5);
      expect(
        await container.read(prefsAliveDoublePodProvider('k').future),
        2.5,
      );
    });

    test('PrefsAliveStrLstPod setValue stores the list', () async {
      await container
          .read(prefsAliveStrLstPodProvider('k').notifier)
          .setValue(['a']);
      expect(
        await container.read(prefsAliveStrLstPodProvider('k').future),
        ['a'],
      );
    });
  });
}
