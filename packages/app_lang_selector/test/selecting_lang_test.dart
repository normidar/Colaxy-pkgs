import 'package:app_lang_selector/app_lang_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('SelectingLang', () {
    test('initial state is null', () {
      expect(container.read(selectingLangProvider), isNull);
    });

    test('setLang updates the state', () {
      container.read(selectingLangProvider.notifier).setLang('ja_JP');
      expect(container.read(selectingLangProvider), 'ja_JP');
    });

    test('setLang can be called repeatedly', () {
      container.read(selectingLangProvider.notifier)
        ..setLang('en_US')
        ..setLang('system_system');
      expect(container.read(selectingLangProvider), 'system_system');
    });
  });
}
