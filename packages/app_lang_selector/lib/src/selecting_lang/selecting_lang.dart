import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selecting_lang.g.dart';

@Riverpod(keepAlive: true)
class SelectingLang extends _$SelectingLang {
  @override
  String? build() {
    return null;
  }

  void setLang(String lang) {
    state = lang;
  }
}
