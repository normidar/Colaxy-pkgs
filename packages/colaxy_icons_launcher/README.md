# colaxy_icons_launcher

A command-line tool that generates launcher icons for a Flutter app on Android,
iOS, macOS, Windows, Linux and Web from a single source image.

This project is a fork of [icons_launcher](https://github.com/mrrhak/icons_launcher)
by [mrrhak](https://github.com/mrrhak), adding **SVG source support**. Everything
else behaves like the original.

## Install

```yaml
dev_dependencies:
  colaxy_icons_launcher: ^0.2.0
```

## Configure

Add a `colaxy_icons_launcher` section to `pubspec.yaml`, or put it in a
`colaxy_icons_launcher.yaml` file next to it:

```yaml
colaxy_icons_launcher:
  image_path: "assets/icon.svg" # PNG or SVG
  platforms:
    android:
      enable: true
    ios:
      enable: true
    macos:
      enable: true
    windows:
      enable: true
    linux:
      enable: true
    web:
      enable: true
```

`image_path` is the fallback for every platform. Any platform may override it
with its own `image_path`, which is useful when one platform needs different
padding or a different shape.

### Options

| Key | Where | Description |
| --- | --- | --- |
| `image_path` | top level, or any platform | Source image. `.svg` and `.png` are both accepted. |
| `platforms.<name>.enable` | each platform | Whether to generate icons for it. |
| `platforms.android.adaptive_foreground_image` | android | Foreground layer of an [adaptive icon]. Requires one of the two background keys below. |
| `platforms.android.adaptive_background_color` | android | Solid background colour, e.g. `"#FFFFFF"`. Mutually exclusive with `adaptive_background_image`. |
| `platforms.android.adaptive_background_image` | android | Background layer image. Mutually exclusive with `adaptive_background_color`. |
| `platforms.android.notification_image` | android | Source for the monochrome notification icon. |
| `platforms.ios.dark_path` | ios | Dark-mode variant (iOS 18+). |
| `platforms.ios.tinted_path` | ios | Tinted variant (iOS 18+). |

[adaptive icon]: https://developer.android.com/develop/ui/views/launch/icon_design_adaptive

## Run

```sh
dart run colaxy_icons_launcher:create
```

### Arguments

| Argument | Description |
| --- | --- |
| `--path <file>` | Read the config from a specific file instead of the default lookup. |
| `--flavor <name>` | Use `colaxy_icons_launcher-<name>.yaml` and write into the matching flavor directories. |
| `--flavors <a,b>` | Run once per flavor. |

Without `--path`, the config is looked up in this order:
`colaxy_icons_launcher-<flavor>.yaml` (when `--flavor` is given), then
`colaxy_icons_launcher.yaml`, then `pubspec.yaml`.

### Flavors

```sh
dart run colaxy_icons_launcher:create --flavor staging
```

reads `colaxy_icons_launcher-staging.yaml`.

## SVG support

This is the one behavioural difference from the upstream package. An `.svg`
source is rasterised in memory at 1024×1024 before entering the normal PNG
pipeline — nothing is written next to your asset. A file referenced by several
platforms is converted once and cached.

## Acknowledgments

Sincere thanks to [mrrhak](https://github.com/mrrhak) for creating and
maintaining the original [icons_launcher](https://github.com/mrrhak/icons_launcher)
library. This project would not exist without their work.

- **Original repository:** https://github.com/mrrhak/icons_launcher
- **Original author:** https://github.com/mrrhak

Forked at `cdbd102aafb7ea96c51162aff23fe668aa95b201`.

## License

MIT. The original license and copyright notice are retained in accordance with
the MIT License requirements.
