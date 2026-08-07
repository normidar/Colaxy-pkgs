import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selecting_lang.g.dart';

/// Called after [SelectingLang.setLang] applies a new language.
///
/// Assign this to observe language changes (e.g. for analytics) without
/// depending on Riverpod: `onLangChanged = (lang) => myLogger(lang);`
void Function(String lang)? onLangChanged;

@Riverpod(keepAlive: true)
class SelectingLang extends _$SelectingLang {
  @override
  String? build() {
    return null;
  }

  void setLang(String lang) {
    state = lang;
    onLangChanged?.call(lang);
  }
}
