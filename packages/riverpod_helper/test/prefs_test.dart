import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_helper/riverpod_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Prefs.set/get round trip', () {
    test('bool', () async {
      await Prefs.set('b', true);
      expect(await Prefs.get<bool>('b', false), isTrue);
    });

    test('int', () async {
      await Prefs.set('i', 42);
      expect(await Prefs.get<int>('i', 0), 42);
    });

    test('double', () async {
      await Prefs.set('d', 1.5);
      expect(await Prefs.get<double>('d', 0), 1.5);
    });

    test('String', () async {
      await Prefs.set('s', 'hello');
      expect(await Prefs.get<String>('s', ''), 'hello');
    });

    test('List<String>', () async {
      await Prefs.set('l', ['a', 'b']);
      expect(await Prefs.get<List<String>>('l', []), ['a', 'b']);
    });
  });

  group('Prefs.set type dispatch', () {
    test('stores values reached through a dynamic call site', () async {
      // `T` is inferred as Object here. The old `T == bool` check rejected this
      // as an unsupported type even though the value is perfectly storable.
      const Object value = true;
      await Prefs.set('dyn', value);

      expect(await Prefs.getOrNull<bool>('dyn'), isTrue);
    });

    test('rejects a type SharedPreferences cannot store', () async {
      expect(
        () => Prefs.set('bad', {'a': 1}),
        throwsA(isA<UnsupportedPrefsTypeError>()),
      );
    });
  });

  group('Prefs read helpers', () {
    test('get falls back to the default when the key is absent', () async {
      expect(await Prefs.get<int>('missing', 7), 7);
    });

    test('getOrNull returns null when the key is absent', () async {
      expect(await Prefs.getOrNull<String>('missing'), isNull);
    });

    test('accepts a nullable type argument', () async {
      // `getOrNull<String?>` is a natural thing to write. Matching `T` against
      // `String` exactly used to reject it as an unsupported type.
      await Prefs.set('s', 'hello');
      expect(await Prefs.getOrNull<String?>('s'), 'hello');
      expect(await Prefs.getOrNull<int?>('missing'), isNull);
      expect(await Prefs.get<List<String>?>('missing', const []), isEmpty);
    });

    test('reading an unsupported type throws instead of a CastError', () async {
      // Previously this fell through to `prefs.get(key) as T?`.
      expect(
        () => Prefs.getOrNull<Duration>('missing'),
        throwsA(isA<UnsupportedPrefsTypeError>()),
      );
    });

    test('getOrSet writes the default the first time only', () async {
      expect(await Prefs.getOrSet<int>('k', 1), 1);
      expect(await Prefs.getOrSet<int>('k', 99), 1);
    });

    test('contains and remove', () async {
      await Prefs.set('k', 'v');
      expect(await Prefs.contains('k'), isTrue);
      await Prefs.remove('k');
      expect(await Prefs.contains('k'), isFalse);
    });
  });

  group('Prefs.update', () {
    test('passes null when nothing is stored yet', () async {
      await Prefs.update<int>('c', (v) => (v ?? 0) + 1);
      expect(await Prefs.getOrNull<int>('c'), 1);
    });

    test('accepts an async updater', () async {
      await Prefs.set('c', 5);
      await Prefs.update<int>('c', (v) async => (v ?? 0) * 2);
      expect(await Prefs.getOrNull<int>('c'), 10);
    });

    test('updateForcePipe uses defaultValue on first call', () async {
      // This used to cast null to T and always throw for a fresh key.
      await Prefs.updateForcePipe<int>(
        'c',
        (v) => v + 1,
        defaultValue: 10,
      );
      expect(await Prefs.getOrNull<int>('c'), 11);
    });

    test('updateForcePipe uses the stored value when present', () async {
      await Prefs.set('c', 3);
      await Prefs.updateForcePipe<int>('c', (v) => v + 1, defaultValue: 100);
      expect(await Prefs.getOrNull<int>('c'), 4);
    });
  });
}
