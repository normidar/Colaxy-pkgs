import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_helper/riverpod_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads a notifier, then lets the event loop turn once so that an auto-dispose
/// provider with no listener actually disposes.
///
/// This ordering is the whole point of this file. `ref.read(...notifier)`
/// followed immediately by a write does *not* reproduce the bug in a test: the
/// mocked SharedPreferences resolves fast enough that disposal has not been
/// processed yet. On a device the platform channel is slow enough that it has,
/// which is why this only ever showed up on real hardware.
Future<NotifierT> disposedNotifier<NotifierT>(
  ProviderContainer container,
  NotifierT Function() read,
) async {
  final notifier = read();
  await Future<void>.delayed(Duration.zero);
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('auto-dispose pods: writing through an already disposed notifier', () {
    test('bool', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final notifier = await disposedNotifier(
        c,
        () => c.read(prefsBoolPodProvider('b').notifier),
      );
      await notifier.setValue(true);
      expect((await SharedPreferences.getInstance()).getBool('b'), isTrue);

      final remover = await disposedNotifier(
        c,
        () => c.read(prefsBoolPodProvider('b').notifier),
      );
      await remover.removeValue();
      expect(
        (await SharedPreferences.getInstance()).containsKey('b'),
        isFalse,
      );
    });

    test('int', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final notifier = await disposedNotifier(
        c,
        () => c.read(prefsIntPodProvider('i').notifier),
      );
      await notifier.setValue(7);
      expect((await SharedPreferences.getInstance()).getInt('i'), 7);

      final remover = await disposedNotifier(
        c,
        () => c.read(prefsIntPodProvider('i').notifier),
      );
      await remover.removeValue();
      expect(
        (await SharedPreferences.getInstance()).containsKey('i'),
        isFalse,
      );
    });

    test('double', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final notifier = await disposedNotifier(
        c,
        () => c.read(prefsDoublePodProvider('d').notifier),
      );
      await notifier.setValue(1.5);
      expect((await SharedPreferences.getInstance()).getDouble('d'), 1.5);

      final remover = await disposedNotifier(
        c,
        () => c.read(prefsDoublePodProvider('d').notifier),
      );
      await remover.removeValue();
      expect(
        (await SharedPreferences.getInstance()).containsKey('d'),
        isFalse,
      );
    });

    test('string', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final notifier = await disposedNotifier(
        c,
        () => c.read(prefsStringPodProvider('s').notifier),
      );
      await notifier.setValue('hi');
      expect((await SharedPreferences.getInstance()).getString('s'), 'hi');

      final remover = await disposedNotifier(
        c,
        () => c.read(prefsStringPodProvider('s').notifier),
      );
      await remover.removeValue();
      expect(
        (await SharedPreferences.getInstance()).containsKey('s'),
        isFalse,
      );
    });

    test('string list', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final notifier = await disposedNotifier(
        c,
        () => c.read(prefsStrLstPodProvider('l').notifier),
      );
      await notifier.setValue(['a', 'b']);
      expect((await SharedPreferences.getInstance()).getStringList('l'), [
        'a',
        'b',
      ]);

      final remover = await disposedNotifier(
        c,
        () => c.read(prefsStrLstPodProvider('l').notifier),
      );
      await remover.removeValue();
      expect(
        (await SharedPreferences.getInstance()).containsKey('l'),
        isFalse,
      );
    });

    test('map', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final notifier = await disposedNotifier(
        c,
        () => c.read(prefsMapPodProvider('m').notifier),
      );
      await notifier.setValue({'a': 1});
      expect(
        (await SharedPreferences.getInstance()).getString('m'),
        '{"a":1}',
      );

      final remover = await disposedNotifier(
        c,
        () => c.read(prefsMapPodProvider('m').notifier),
      );
      await remover.removeValue();
      expect(
        (await SharedPreferences.getInstance()).containsKey('m'),
        isFalse,
      );
    });
  });

  group('keep-alive pods: writing through a notifier held across a turn', () {
    test('bool', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final notifier = await disposedNotifier(
        c,
        () => c.read(prefsAliveBoolPodProvider('b').notifier),
      );
      await notifier.setValue(true);
      expect((await SharedPreferences.getInstance()).getBool('b'), isTrue);

      await notifier.removeValue();
      expect(
        (await SharedPreferences.getInstance()).containsKey('b'),
        isFalse,
      );
    });

    test('int', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final notifier = await disposedNotifier(
        c,
        () => c.read(prefsAliveIntPodProvider('i').notifier),
      );
      await notifier.setValue(7);
      expect((await SharedPreferences.getInstance()).getInt('i'), 7);

      await notifier.removeValue();
      expect(
        (await SharedPreferences.getInstance()).containsKey('i'),
        isFalse,
      );
    });

    test('double', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final notifier = await disposedNotifier(
        c,
        () => c.read(prefsAliveDoublePodProvider('d').notifier),
      );
      await notifier.setValue(1.5);
      expect((await SharedPreferences.getInstance()).getDouble('d'), 1.5);

      await notifier.removeValue();
      expect(
        (await SharedPreferences.getInstance()).containsKey('d'),
        isFalse,
      );
    });

    test('string', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final notifier = await disposedNotifier(
        c,
        () => c.read(prefsAliveStringPodProvider('s').notifier),
      );
      await notifier.setValue('hi');
      expect((await SharedPreferences.getInstance()).getString('s'), 'hi');

      await notifier.removeValue();
      expect(
        (await SharedPreferences.getInstance()).containsKey('s'),
        isFalse,
      );
    });

    test('string list', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final notifier = await disposedNotifier(
        c,
        () => c.read(prefsAliveStrLstPodProvider('l').notifier),
      );
      await notifier.setValue(['a', 'b']);
      expect((await SharedPreferences.getInstance()).getStringList('l'), [
        'a',
        'b',
      ]);

      await notifier.removeValue();
      expect(
        (await SharedPreferences.getInstance()).containsKey('l'),
        isFalse,
      );
    });

    test('map', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final notifier = await disposedNotifier(
        c,
        () => c.read(prefsAliveMapPodProvider('m').notifier),
      );
      await notifier.setValue({'a': 1});
      expect(
        (await SharedPreferences.getInstance()).getString('m'),
        '{"a":1}',
      );

      await notifier.removeValue();
      expect(
        (await SharedPreferences.getInstance()).containsKey('m'),
        isFalse,
      );
    });
  });

  group('writePrefsValue keeps the provider alive for the write', () {
    // The pods' own writes finish within a microtask under mocked
    // SharedPreferences, so they cannot show the keep-alive window directly.
    // Drive the guard with a write we control instead.
    final refPod = Provider.autoDispose<Ref>((ref) => ref);

    test('the provider survives an event loop turn mid-write', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ref = c.read(refPod);

      final blocked = Completer<void>();
      var published = false;
      final pending = writePrefsValue(
        ref: ref,
        key: 'k',
        write: (prefs, key) async {
          await blocked.future;
          await prefs.setString(key, 'v');
        },
        publishState: () => published = true,
      );

      // Without the keep-alive link this auto-dispose provider would be gone
      // by now, and the rest of the write would run against a dead Ref.
      await Future<void>.delayed(Duration.zero);
      expect(c.exists(refPod), isTrue);

      blocked.complete();
      await pending;
      expect(published, isTrue);
      expect((await SharedPreferences.getInstance()).getString('k'), 'v');
    });

    test('the link is released once the write finishes', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ref = c.read(refPod);

      await writePrefsValue(
        ref: ref,
        key: 'k',
        write: (prefs, key) => prefs.setString(key, 'v'),
        publishState: () {},
      );
      await Future<void>.delayed(Duration.zero);

      // The link must not outlive the write, or writing to an auto-dispose pod
      // would quietly turn it into a keep-alive one.
      expect(c.exists(refPod), isFalse);
    });

    test('an already disposed provider still gets its write to disk', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ref = c.read(refPod);
      await Future<void>.delayed(Duration.zero);

      var published = false;
      await writePrefsValue(
        ref: ref,
        key: 'k',
        write: (prefs, key) => prefs.setString(key, 'v'),
        publishState: () => published = true,
      );

      // There is no live state left to publish; the next read of the provider
      // picks the value up from SharedPreferences.
      expect(published, isFalse);
      expect((await SharedPreferences.getInstance()).getString('k'), 'v');
    });

    test('a watching widget still sees the new value, not a reload', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(prefsStringPodProvider('s').future);

      final seen = <AsyncValue<String?>>[];
      c.listen(prefsStringPodProvider('s'), (_, next) => seen.add(next));

      await c.read(prefsStringPodProvider('s').notifier).setValue('v');

      expect(seen.map((s) => s.value), ['v']);
      expect(seen.any((s) => s.isLoading), isFalse);
    });
  });
}
