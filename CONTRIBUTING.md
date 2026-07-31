# Contributing

Thanks for helping out. This repo is a [pub workspace] managed with
[melos](https://melos.invertase.dev/); a single resolve at the root covers every
package.

[pub workspace]: https://dart.dev/tools/pub/workspaces

## Setup

```sh
make setup
```

That installs the toolchain pinned in `mise.toml`, activates melos, and resolves
the workspace. Do not use `fvm` — the version pin lives in `mise.toml`.

## Before opening a pull request

```sh
make ci      # analyze + test
make format  # then commit the result
```

CI runs the same three things (`format`/`fix` diff check, `analyze`, `test`) and
fails on any difference, so run them locally first.

A few things worth knowing:

- **`dart analyze` fails on info-level lints too.** The shared config lives in
  the root `analysis_options.yaml`; packages `include:` it and only add their own
  overrides.
- **Generated code is committed.** If you touch anything annotated for
  `riverpod_generator`, `build_version` or `auto_exporter`, run `make build` and
  commit the regenerated `*.g.dart`. Generated files are excluded from analysis,
  so stale output will not show up until something fails to compile.
- **Translations shipped by a package must be namespaced** with the package name,
  e.g. `app_theme_picker:tile_title`. Bare keys collide with the host app's.

## Versioning and changelogs

Packages are published from this repo with `melos publish`. When you change a
package:

1. Bump its `version` in `pubspec.yaml`. Everything here is pre-1.0, so a
   breaking change is a **minor** bump.
2. Add a matching entry at the top of that package's `CHANGELOG.md`, with a
   `### Breaking` section when the API changed.
3. If the change is breaking, widen the constraint in any package that depends
   on it.

## Reporting a problem

Open an issue at https://github.com/normidar/colaxy-pkgs/issues. For security
issues see [SECURITY.md](SECURITY.md).
