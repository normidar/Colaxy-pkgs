## 0.3.0

### Breaking
- Removed the ~80 `<Name>ThemeMock` classes and matching `<name>ThemeOverride`
  values. Use `themeOverride(FlexScheme.x)` / `themeModeOverride(ThemeMode.x)`,
  or `FixedThemePod` / `FixedThemeModePod` directly. They were shipped in `lib/`
  and so ended up in every app's binary.
- `availableSchemes` is `Set<FlexScheme>` instead of `Set<String>`. Scheme names
  were compared as strings, so a typo silently filtered out everything.
- `ThemeModePod` defaults to `ThemeMode.system` instead of `ThemeMode.light`.
- The default scheme is `FlexScheme.material`, and is now configurable through
  the `defaultFlexScheme` variable (it was hardcoded to `sakura`).

### Fixed
- The `AppBar` on `PickThemePage` no longer tries to render a scrollable error
  view as its title.

### Changed
- `PickThemePage.size` defaults to 70, matching `ThemePickTile`.

## 0.2.0

### Breaking
- Namespaced the bundled translation keys with `app_theme_picker:`. The generic
  `theme` and `tile_title` keys collided with host app keys.

## 0.1.3+4

 - **CHORE**: upgrade riverpod_generator to ^4.0.0 and riverpod_lint to ^3.1.0.

## 0.1.3+3

 - **FIX**: resolve crash risks and stale state issues found in code review.
 - **FIX**: reset repo link and homepage link.
 - **FIX**: use melos.

## 0.1.3+2

 - Update a dependency to the latest release.

## 0.1.3+1

 - **FIX**: reset repo link and homepage link.
 - **FIX**: use melos.

## 0.1.3

- Add overrides for theme and theme mode.

## 0.1.2

- Add mocks for theme and theme mode.

## 0.1.1

- Add theme mode pod.

## 0.1.0

- update riverpod.

## 0.0.1

- Initial release.
