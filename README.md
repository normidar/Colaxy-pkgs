# Colaxy-pkgs

A monorepo of Flutter/Dart packages used to build Colaxy apps. See
[example/README.md](example/README.md) for how to put them together in an app.

## Packages

| Package | pub.dev | What it does |
| --- | --- | --- |
| [`app_info_tile`](packages/app_info_tile) | [![pub](https://img.shields.io/pub/v/app_info_tile.svg)](https://pub.dev/packages/app_info_tile) | Settings tile showing app name, version and the license page. |
| [`app_lang_selector`](packages/app_lang_selector) | [![pub](https://img.shields.io/pub/v/app_lang_selector.svg)](https://pub.dev/packages/app_lang_selector) | Language picker, plus the asset loader that merges each package's translations into the app's. |
| [`app_theme_picker`](packages/app_theme_picker) | [![pub](https://img.shields.io/pub/v/app_theme_picker.svg)](https://pub.dev/packages/app_theme_picker) | Colour scheme and light/dark picker built on FlexColorScheme, with the choice persisted. |
| [`colaxy_adaptive_scaffold`](packages/colaxy_adaptive_scaffold) | [![pub](https://img.shields.io/pub/v/colaxy_adaptive_scaffold.svg)](https://pub.dev/packages/colaxy_adaptive_scaffold) | Scaffold that switches between bottom navigation, a rail and a drawer as the window changes. |
| [`colaxy_icons_launcher`](packages/colaxy_icons_launcher) | [![pub](https://img.shields.io/pub/v/colaxy_icons_launcher.svg)](https://pub.dev/packages/colaxy_icons_launcher) | CLI that generates launcher icons for every platform, from PNG **or SVG**. |
| [`colaxy_localization`](packages/colaxy_localization) | [![pub](https://img.shields.io/pub/v/colaxy_localization.svg)](https://pub.dev/packages/colaxy_localization) | CLI that turns per-locale JSON into Fastlane store metadata and native app-name resources. |
| [`colaxy_screenshot`](packages/colaxy_screenshot) | [![pub](https://img.shields.io/pub/v/colaxy_screenshot.svg)](https://pub.dev/packages/colaxy_screenshot) | Automated store screenshots across devices and languages, wired for Fastlane. |
| [`colaxy_store_console`](packages/colaxy_store_console) | [![pub](https://img.shields.io/pub/v/colaxy_store_console.svg)](https://pub.dev/packages/colaxy_store_console) | One API over Google Play Console and App Store Connect: reviews, replies, sales, analytics and vitals. |
| [`colaxy_tutorial`](packages/colaxy_tutorial) | [![pub](https://img.shields.io/pub/v/colaxy_tutorial.svg)](https://pub.dev/packages/colaxy_tutorial) | Onboarding tours and coach marks, with "already seen" state handled for you. |
| [`riverpod_helper`](packages/riverpod_helper) | [![pub](https://img.shields.io/pub/v/riverpod_helper.svg)](https://pub.dev/packages/riverpod_helper) | Typed SharedPreferences access and ready-made Riverpod providers over it. |

## Getting started

The toolchain is pinned in [`mise.toml`](mise.toml), and the repo is a single
[pub workspace], so one resolve at the root covers every package.

```sh
mise install                     # Flutter/Dart at the pinned version
dart pub global activate melos
flutter pub get                  # resolves the whole workspace
```

Or just `make setup`.

[pub workspace]: https://dart.dev/tools/pub/workspaces

## Common commands

`make help` lists everything. The main ones:

| Command | Description |
| --- | --- |
| `make analyze` | `dart analyze` across all packages |
| `make test` | Tests across all packages (`flutter test` or `dart test` as appropriate) |
| `make format` / `make fix` | Formatting and `dart fix` |
| `make build` | `build_runner` where it's needed |
| `make ci` | What CI runs |

Every one of these maps to a `melos run <script>` defined in the root
[`pubspec.yaml`](pubspec.yaml), so `melos run analyze` etc. work too.

## Repository layout

```
packages/               the published packages
example/                an app wiring several of them together
docs/                   working notes, e.g. docs/IMPROVEMENTS.md
analysis_options.yaml   shared lint config; packages include this
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
