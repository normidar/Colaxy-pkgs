## 0.3.1

### Changed
- The compiled Flutter version line now reads "Powered by Flutter {version}",
  fixed in English rather than translated (it names the framework, not app
  copy), and renders in a smaller, muted style instead of the dialog's title
  text style, so it reads as an aside rather than competing with the app name
  and version above it.

## 0.3.0

### Added
- The info dialog now also shows the Flutter version the app was compiled
  with, via `FlutterVersion.version` (`package:flutter/services.dart`,
  Flutter 3.32+). The line is omitted when `FlutterVersion.version` is `null`
  (e.g. when the app wasn't built with `flutter run`/`flutter build`, which is
  what populates it).

## 0.2.1

### Fixed
- Narrowed the `riverpod_annotation`/`riverpod_generator` version constraints
  and regenerated `app_info_pod.g.dart`. `riverpod_annotation` exact-pins a
  specific `riverpod` core release internally, and this package's previous
  `^4.0.0` range let a host app's pub resolution drift to a newer
  `riverpod_annotation` (and therefore a newer `riverpod` core) than the
  committed generated code was built against, breaking compilation with
  errors like `runBuild`/`handleValue` signature mismatches.
- Bumped the `app_lang_selector` dependency to `^0.3.1` for the same fix.

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
- Widget tests covering the dialog, the app-name fallback and the license page.

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
