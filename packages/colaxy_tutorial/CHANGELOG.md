## 0.3.0

### Fixed
- The "shown" flag is persisted before navigating away from a tutorial page.
  The write was fire-and-forget and could lose the race, so the tutorial
  reappeared.
- `showTutorial` awaits its delay instead of scheduling fire-and-forget work,
  so callers can await it and a failed save is no longer swallowed.

### Added
- Tests. This package previously had no `test/` directory at all, so it was
  silently skipped by the test runner.

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
