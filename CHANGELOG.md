# Changelog

## 0.2.0

### Added
- `bond mcp`: an MCP server (stdio) for AI coding agents such as Claude Code. It answers from
  the exact bond_* versions a project resolves (`.dart_tool/package_config.json`):
  - `packages`, `package_overview` (public libraries, README, example, latest changes),
    `api` (the public API read from the package source: declarations, constructors, methods,
    fields, signatures and docs; filter by symbol, paged) and `migration`;
  - `create_model`, `create_widget`, `create_service_provider` and `create_project`, which
    write only inside the client's roots and never overwrite files;
  - resources `bond://package/{name}/{readme|changelog|example}` and the migration guides;
  - the `bond_review` prompt (review a diff against the Bond conventions).
- The generators return the files they created and the next steps (CLI and MCP share them).

### Changed
- `bond create project` no longer depends on the process's current directory internally.
- `bond create service_provider` prints where to register the provider (`lib/app/app.dart`).

## 0.1.0

Targets the flutter-bond `v2.0.0` template (Flutter 3.47.7, Android Kotlin
DSL / AGP 9, iOS 15, bond_core 0.1.0).

### Breaking

- Requires Dart 3.13 or later (`sdk: ^3.13.0`).
- `bond create project` clones the template at `--ref` (default `v2.0.0`)
  from `--template-url` (default
  `https://github.com/flutterbond/flutter-bond.git`) instead of the
  default-branch HEAD. Use `--ref v1.0.0` for the legacy template.
- `bond create project` runs `flutter pub get` again (through `fvm` when the
  template has an `.fvmrc`) and creates an initial git commit; pass
  `--no-pub-get` to skip `pub get`.
- Generators write to `lib/features/<feature>/` (`data/models/`,
  `presentation/widgets/`, `<name>_service_provider.dart`); `--feature`
  defaults to the snake_case name.
- The model generator always emits a json_serializable `Model`; `-j` and
  `-e` are ignored. The service provider stub targets the bond_core 0.1.0
  `ServiceProvider` and `ResponseDecoding.factories` API.
- Consumer widgets use `flutter_riverpod` instead of `hooks_riverpod`.
- Prompts and spinners use `mason_logger` instead of `interact`; without a
  terminal, missing options fail with a usage error (exit code 64) instead
  of prompting.
- `bond update android_app_id` also renames the `namespace` and moves the
  Kotlin package.
- `add google_auth` adds `google_sign_in: ^7.2.0`.
- The `dto` command (never registered) was removed.

### Changed

- Native project edits are built in (no `native_project_manipulator`, no
  Ruby `xcodeproj` gem) and understand the Kotlin DSL:
  `applicationId`/`namespace`, per-flavor `strings.xml` app names,
  `MainActivity` package moves for any number of segments (no longer
  reversed), `package_name` in every `google-services.json`, iOS bundle IDs
  of all build configurations (`.staging` kept), `BUNDLE_ID` in each
  `GoogleService-Info.plist`, `CFBundleName`/`CFBundleDisplayName`, and
  `iosBundleId`/app ID literals in Dart sources.
- iOS setup runs on every OS, not only macOS.
- `create project` accepts `--app-name` and kebab-case aliases
  (`--project-name`, `--bundle-id`, `--application-id`).
- Options passed as flags are validated; iOS bundle IDs such as
  `com.example.app` are no longer rejected.
- Commands exit with a non-zero code on failure.

### Fixed

- Model and widget names are converted to snake_case file names properly
  (`UserDetail` -> `user_detail.dart`, class `UserDetail`).
- `create model` runs a full `build_runner build`. The old `--build-filter` was quoted wrongly and matched
  nothing; with build_runner 2.16 a filter would also delete the project's other generated files.
- Every `git`, `flutter` and `build_runner` exit code is checked.
- `add google_auth` looks for the flavored Firebase files, edits
  `Info.plist` idempotently, and no longer overwrites existing env values.
- The published archive no longer ships IDE files or a stray generated
  project.

## 0.0.4+3

- Disable the format and `pub get` steps of `create project`.

## 0.0.4+

- make native_project_manipulator to read from repo directly for development proposes

## 0.0.4

- fix windows create project command bug.
- improve readme file.

* new commands

## 0.0.3

* new commands

## 0.0.2

* update readme file.

## 0.0.1

* initial release.
