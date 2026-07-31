## 0.2.0

### Breaking
- `LocaleApp.getLocaleUnits` takes a `mainLocale` argument (default `en-US`)
  instead of hardcoding it.
- `LocaleApp` and `LocaleUnit` take a `rootPath`, so they can target a project
  other than the current working directory.
- Failures now throw `StateError` with a message naming the locale, key or file
  at fault, rather than `Exception` or a bare null-check error.

### Fixed
- `LocaleApp.getLocaleApps` returned a list of identical `const LocaleApp()`
  values, discarding the directories it had just scanned.
- Unmapped locales produced a bare "Null check operator used on a null value";
  they now name the locale and list the supported ones.
- The App Store keyword check is case-insensitive and matches whole words, so
  `iOS` is caught and `radios` is not rejected.
- A malformed `Info.plist` fails the run instead of being logged and ignored.
- `fitLocale` updates only the `app_name` entry in `strings.xml`. The file was
  overwritten wholesale, dropping every other string resource in it.
- `updateManifestAppName` no longer strips every comment from
  `AndroidManifest.xml`.
- Store length limits count grapheme clusters, so an emoji or combining sequence
  no longer inflates the count.

### Added
- `bin/gen.dart` accepts `--root`, `--main-locale` and `--help`.
- `AndroidNameLocalization` and `IOSNameLocalization` accept a `rootPath`, so
  they can target a project other than the current working directory.

## 0.1.0+2

 - **FIX**: resolve crash risks and stale state issues found in code review.
 - **FIX**: move package to monorepo.

## 0.1.0+1

 - **FIX**: move package to monorepo.

## 0.1.0

- Fix some bugs.

## 0.0.2

- Add languages support.

## 0.0.1

- Initial release.
