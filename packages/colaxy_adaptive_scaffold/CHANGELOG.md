## 0.1.0

### Fixed
- Pages keep their state when switching destinations. Only the selected page
  was built before, so scroll positions and form input were discarded on every
  switch; all pages now live in an `IndexedStack`.
- An empty `items` list no longer throws from `initialIndex.clamp(0, -1)` in
  release builds.
- The rail divider uses `Theme.dividerColor` instead of a hardcoded
  `Colors.grey[300]`.
- `MediaQuery.sizeOf` is used instead of `MediaQuery.of(...).size`.

### Breaking
- The drawer header is no longer rendered by default. It previously showed a
  hardcoded, untranslatable `'Menu'`; pass `drawerTitle` to bring it back.

### Added
- `AdaptiveScaffold.onDestinationSelected` and `AdaptiveScaffold.drawerTitle`.
- `NavigationItem.selectedIcon` and `NavigationItem.tooltip`.

## 0.0.1+4

 - **FIX**: resolve crash risks and stale state issues found in code review.
 - **FIX**: update auto_exporter library.
 - **FIX**: give example workspace members unique package names.
 - **FIX**: include example apps as pub workspace members.
 - **FIX**: reset repo link and homepage link.
 - **FIX**: format and fix.
 - **FIX**: use melos.

## 0.0.1+3

 - **FIX**: update auto_exporter library.

## 0.0.1+2

 - **FIX**: give example workspace members unique package names.
 - **FIX**: include example apps as pub workspace members.

## 0.0.1+1

 - **FIX**: reset repo link and homepage link.
 - **FIX**: format and fix.
 - **FIX**: use melos.

## 0.0.1

- Initial release.
