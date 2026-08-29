## 0.3.2

### Changed
- Widened the `app_lang_selector` dependency to `^0.4.0`, the release that adds
  Traditional Chinese (`zh-TW`). This package already shipped `zh-TW.json`, so
  the whole set of colaxy packages an app loads through `PkgsAssetLoader` now
  covers the same locale.

## 0.3.1

### Fixed
- Bumped the `app_lang_selector` dependency to `^0.3.1` and `flutter_riverpod`'s
  lower bound. `TutorialResetTile` pulls in `app_lang_selector`'s
  `selectingLangProvider`, and the previously-published `app_lang_selector`
  versions could resolve to a `riverpod` core newer than their generated code
  supported, breaking compilation for any app using both this package and a
  recent Riverpod release. See `app_lang_selector`'s 0.3.1 changelog for
  details.

## 0.3.0

### Fixed
- The "shown" flag is persisted before navigating away from a tutorial page.
  The write was fire-and-forget and could lose the race, so the tutorial
  reappeared.
- `showTutorial` awaits its delay instead of scheduling fire-and-forget work,
  so callers can await it and a failed save is no longer swallowed.
- `TutorialContent` and the tutorial page chrome take their colours from the
  theme. Hardcoded white backgrounds with black text were unreadable under a
  dark theme.
- `guardTutorialPage` falls through to the next page if reading the "shown" flag
  fails, instead of sitting on a spinner forever.
- The stored `showed_ids` list is de-duplicated and sorted rather than growing
  unboundedly.

### Added
- Tests. This package previously had no `test/` directory at all, so it was
  silently skipped by the test runner.
- A page indicator on multi-page tutorials.
- `TutorialTool.highlightColor` and `TutorialTool.contentTextStyle`.

### Changed
- `VersionRecorder` documents that it stores build numbers, and exposes
  `recordedBuildNumbers()`.

### Removed
- `DecideShowingConfig` and friends, which were never referenced or exported.

## 0.2.0+2

 - **FIX**: resolve crash risks and stale state issues found in code review.
 - **FIX**: move package to monorepo.

## 0.2.0+1

 - **FIX**: move package to monorepo.

## 0.2.0

- Add TutorialResetTile component.

## 0.1.1

- Add guardTutorialPage method.

## 0.1.0

- Add Tutorial Page feature.

## 0.0.2

- Add localization support.

## 0.0.1

- Initial release.
