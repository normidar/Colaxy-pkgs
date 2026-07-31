## 0.2.0

### Breaking
- Namespaced the bundled translation keys with `app_info_tile:` so they cannot
  collide with the host app's keys (`app_info_tile_title` is now
  `app_info_tile:title`).
- `AppInfoTile.getAlertDialog` is now private.

### Fixed
- The dialog no longer depends on the host app defining an `app_name`
  translation key; it falls back to the platform-reported app name. Pass
  `appName` to override.
- The loading state renders as a `ListTile` instead of a centered spinner, so a
  settings list no longer jumps when the package info resolves.
- The license button uses the theme's primary color instead of a hardcoded
  `Colors.blue`.

### Added
- `AppInfoTile.appName`, `applicationIcon` and `applicationLegalese`.

## 0.1.0+4

 - **CHORE**: upgrade riverpod_generator to ^4.0.0 and riverpod_lint to ^3.1.0.

## 0.1.0+3

 - **FIX**: reset repo link and homepage link.
 - **FIX**: use melos.

## 0.1.0+2

 - Update a dependency to the latest release.

## 0.1.0+1

 - **FIX**: reset repo link and homepage link.
 - **FIX**: use melos.

## 0.1.0

- Update riverpod.

## 0.0.3

- Update package_info_plus to 9.0.0.

## 0.0.2

- Fix bug.

## 0.0.1

- Initial release.
