import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_helper/riverpod_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Prefs.set / Prefs.get', () {
    test('stores and returns a bool', () async {
      await Prefs.set<bool>('boolKey', true);
      expect(await Prefs.get<bool>('boolKey', false), isTrue);
    });

    test('stores and returns an int', () async {
      await Prefs.set<int>('intKey', 42);
      expect(await Prefs.get<int>('intKey', 0), 42);
    });

    test('stores and returns a double', () async {
      await Prefs.set<double>('doubleKey', 3.14);
      expect(await Prefs.get<double>('doubleKey', 0), 3.14);
    });

    test('stores and returns a String', () async {
      await Prefs.set<String>('stringKey', 'hello');
      expect(await Prefs.get<String>('stringKey', ''), 'hello');
    });

    test('stores and returns a List<String>', () async {
      await Prefs.set<List<String>>('listKey', ['a', 'b']);
      expect(await Prefs.get<List<String>>('listKey', []), ['a', 'b']);
    });

    test('set returns the stored value', () async {
      expect(await Prefs.set<int>('intKey', 7), 7);
    });

    test('set throws for an unsupported type', () async {
      expect(
        () => Prefs.set<Map<String, int>>('mapKey', {'a': 1}),
        throwsA(isA<Exception>()),
      );
    });

    test('get returns defaultValue when key does not exist', () async {
      expect(await Prefs.get<int>('missing', 99), 99);
      expect(await Prefs.get<String>('missing', 'default'), 'default');
    });
  });

  group('Prefs.getOrNull', () {
    test('returns null when key does not exist', () async {
      expect(await Prefs.getOrNull<int>('missing'), isNull);
    });

    test('returns the stored value when key exists', () async {
      await Prefs.set<String>('key', 'value');
      expect(await Prefs.getOrNull<String>('key'), 'value');
    });
  });

  group('Prefs.getOrSet', () {
    test('sets and returns default when key does not exist', () async {
      expect(await Prefs.getOrSet<int>('key', 10), 10);
      expect(await Prefs.getOrNull<int>('key'), 10);
    });

    test('returns the existing value when key exists', () async {
      await Prefs.set<int>('key', 5);
      expect(await Prefs.getOrSet<int>('key', 10), 5);
    });
  });

  group('Prefs.contains / Prefs.remove', () {
    test('contains reflects key existence', () async {
      expect(await Prefs.contains('key'), isFalse);
      await Prefs.set<bool>('key', true);
      expect(await Prefs.contains('key'), isTrue);
    });

    test('remove deletes the key', () async {
      await Prefs.set<int>('key', 1);
      expect(await Prefs.remove('key'), isTrue);
      expect(await Prefs.contains('key'), isFalse);
    });
  });

  group('Prefs.update', () {
    test('updater receives null when key does not exist', () async {
      await Prefs.update<int>('counter', (value) => (value ?? 0) + 1);
      expect(await Prefs.getOrNull<int>('counter'), 1);
    });

    test('updater receives the current value', () async {
      await Prefs.set<int>('counter', 10);
      await Prefs.update<int>('counter', (value) => (value ?? 0) + 1);
      expect(await Prefs.getOrNull<int>('counter'), 11);
    });
  });
}
