## 0.2.0

### Breaking
- `Prefs.updateForcePipe` requires a `defaultValue`. It previously cast a
  missing value to `T`, which always threw on the first call for a key.
- `Prefs.get`/`Prefs.getOrNull` throw `UnsupportedPrefsTypeError` for types
  SharedPreferences cannot store, instead of falling through to an unchecked
  cast that failed later and elsewhere.

### Fixed
- Regenerated the `.g.dart` files. The committed ones were generated against an
  older riverpod and did not compile against riverpod 3.x.
- `Prefs.set` dispatches on the runtime value rather than the static type `T`,
  so storing a value reached through a `dynamic`/`Object` variable works.
- `RiverpodErrorView` no longer shows a raw stack trace to end users in release
  builds, and no longer calls `print` from `build`.
- Writing a value updates the provider state directly instead of calling
  `ref.invalidateSelf()`, which re-read SharedPreferences and bounced the
  provider through `AsyncLoading` on every write.
- The map pods report which key holds invalid JSON instead of throwing an
  unattributed `FormatException`/`CastError`.

### Added
- `Prefs.update` accepts an async updater.
- `reportRiverpodError`, for sending a provider error to `FlutterError`.
- Tests for `Prefs`.
- `PrefsAliveMapPod`. A map was the only type with no keep-alive variant.

## 0.1.0+3

 - **CHORE**: upgrade riverpod_generator to ^4.0.0 and riverpod_lint to ^3.1.0.

## 0.1.0+2

 - **FIX**: reset repo link and homepage link.
 - **FIX**: use melos.

## 0.1.0+1

 - **FIX**: reset repo link and homepage link.
 - **FIX**: use melos.

## [0.1.0] - 2025-11-14

- Update riverpod dependencies.

## [0.0.3] - 2025-08-10

- New start for riverpod_helper.

## [0.0.2] - 2024-06-15

- second release

## 0.0.1

- first release
