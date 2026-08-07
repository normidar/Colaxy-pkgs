import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod_helper/riverpod_helper.dart';

part 'theme_pod.g.dart';

/// Scheme used until the user picks one.
///
/// Assign at startup (before the provider is first read) to change it:
/// `defaultFlexScheme = FlexScheme.blue;`
FlexScheme defaultFlexScheme = FlexScheme.material;

/// Called after [ThemePod.changeTheme] persists a new scheme.
///
/// Assign this to observe theme changes (e.g. for analytics) without
/// depending on Riverpod: `onThemeChanged = (scheme) => myLogger(scheme);`
void Function(FlexScheme scheme)? onThemeChanged;

@Riverpod(keepAlive: true)
class ThemePod extends _$ThemePod {
  final _prefKey = 'app_theme_picker:theme';

  @override
  Future<FlexScheme> build() async {
    final themeIndex = await ref.read(
      prefsAliveIntPodProvider(_prefKey).future,
    );
    // Guard against out-of-range indices (e.g. a value saved by a version
    // of flex_color_scheme with a different scheme list).
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < FlexScheme.values.length) {
      return FlexScheme.values[themeIndex];
    }
    return defaultFlexScheme;
  }

  Future<void> changeTheme(FlexScheme theme) async {
    await ref
        .read(prefsAliveIntPodProvider(_prefKey).notifier)
        .setValue(theme.index);
    state = AsyncData(theme);
    onThemeChanged?.call(theme);
  }
}
