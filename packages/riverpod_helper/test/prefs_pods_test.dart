import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_helper/riverpod_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences prefixes every key it stores.
String _stored(String key) => 'flutter.$key';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('typed pods round trip', () {
    test('bool', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(prefsAliveBoolPodProvider('b').future);

      await c.read(prefsAliveBoolPodProvider('b').notifier).setValue(true);
      expect(c.read(prefsAliveBoolPodProvider('b')).value, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('b'), isTrue);
    });

    test('int', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(prefsAliveIntPodProvider('i').future);

      await c.read(prefsAliveIntPodProvider('i').notifier).setValue(7);
      expect(c.read(prefsAliveIntPodProvider('i')).value, 7);
    });

    test('string', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(prefsAliveStringPodProvider('s').future);

      await c.read(prefsAliveStringPodProvider('s').notifier).setValue('hi');
      expect(c.read(prefsAliveStringPodProvider('s')).value, 'hi');
    });

    test(
      'map, including the keep-alive variant that used to be missing',
      () async {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        await c.read(prefsAliveMapPodProvider('m').future);

        await c.read(prefsAliveMapPodProvider('m').notifier).setValue({
          'a': 1,
          'b': 'two',
        });
        expect(c.read(prefsAliveMapPodProvider('m')).value, {
          'a': 1,
          'b': 'two',
        });

        // A fresh container reads it back through the JSON decoder.
        final reopened = ProviderContainer();
        addTearDown(reopened.dispose);
        expect(
          await reopened.read(prefsAliveMapPodProvider('m').future),
          {'a': 1, 'b': 'two'},
        );
      },
    );
  });

  group('writes do not bounce through a loading state', () {
    test('setValue moves straight to the new value', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(prefsAliveStringPodProvider('s').future);

      final seen = <AsyncValue<String?>>[];
      c.listen(prefsAliveStringPodProvider('s'), (_, next) => seen.add(next));

      await c.read(prefsAliveStringPodProvider('s').notifier).setValue('v');

      // `ref.invalidateSelf()` used to re-read SharedPreferences, so observers
      // saw AsyncLoading before the value and any dependent UI flickered.
      expect(seen.map((s) => s.value), ['v']);
      expect(seen.any((s) => s.isLoading), isFalse);
    });

    test('removeValue moves straight to null', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(prefsAliveStringPodProvider('s').notifier).setValue('v');

      final seen = <AsyncValue<String?>>[];
      c.listen(prefsAliveStringPodProvider('s'), (_, next) => seen.add(next));

      await c.read(prefsAliveStringPodProvider('s').notifier).removeValue();

      expect(seen.map((s) => s.value), [null]);
      expect(seen.any((s) => s.isLoading), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('s'), isFalse);
    });
  });

  group('map pod decoding', () {
    test('reports the key when the stored value is not valid JSON', () async {
      SharedPreferences.setMockInitialValues({_stored('bad'): 'not json'});
      final c = ProviderContainer();
      addTearDown(c.dispose);

      Object? error;
      c.listen(
        prefsAliveMapPodProvider('bad'),
        (_, next) => error ??= next.error,
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(error, isA<FormatException>());
      expect((error! as FormatException).message, contains('"bad"'));
    });

    test('reports the key when the stored JSON is not an object', () async {
      SharedPreferences.setMockInitialValues({_stored('arr'): '[1,2,3]'});
      final c = ProviderContainer();
      addTearDown(c.dispose);

      Object? error;
      c.listen(
        prefsAliveMapPodProvider('arr'),
        (_, next) => error ??= next.error,
        fireImmediately: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(error, isA<FormatException>());
      expect(
        (error! as FormatException).message,
        allOf(contains('"arr"'), contains('expected a JSON object')),
      );
    });
  });
}
