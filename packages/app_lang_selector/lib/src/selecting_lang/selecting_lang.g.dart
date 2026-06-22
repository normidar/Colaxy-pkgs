// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selecting_lang.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SelectingLang)
const selectingLangProvider = SelectingLangProvider._();

final class SelectingLangProvider
    extends $NotifierProvider<SelectingLang, String?> {
  const SelectingLangProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'selectingLangProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$selectingLangHash();

  @$internal
  @override
  SelectingLang create() => SelectingLang();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$selectingLangHash() => r'6cfa67505b386097fd1cf974302ab219f71718d4';

abstract class _$SelectingLang extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String?, String?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<String?, String?>, String?, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
