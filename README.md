# Bond CLI

Bond CLI is a command-line tool for streamlining Flutter Bond app development.

## Requirements

- Dart 3.13 or later (Flutter 3.47.7 or later).
- `git`

## Installation

```bash
dart pub global activate bond_cli
```

## Usage

Create a project from the [flutter-bond](https://github.com/flutterbond/flutter-bond)
template:

```bash
bond create project \
  --project-name my_dream_project \
  --bundle-id com.example.dream \
  --application-id com.example.dream
```

Missing options are prompted for. Other options:

| Option | Default | |
|---|---|---|
| `--app-name` | project name in Title Case | Name on the home screen (Android `strings.xml`, iOS `CFBundleDisplayName`). |
| `--template-url` | `https://github.com/flutterbond/flutter-bond.git` | Git URL or local path of the template. |
| `--ref` | `v2.0.0` | Template branch or tag. |
| `--[no-]pub-get` | on | Run `flutter pub get` in the new project. |

The project is cloned into `./<project_name>`, renamed (Dart package and
imports, Android application ID, namespace and Kotlin package, iOS bundle IDs,
Firebase config IDs, app names; the staging flavor keeps its `.staging`
suffix), and committed as a fresh git repository.

Run these from the root of a Bond project:

```bash
bond update app_name --name "Dream"
bond update android_app_id --applicationId com.example.dream
bond update ios_bundle_id --bundleId com.example.dream

bond create model --name UserDetail --feature profile
bond create service_provider --name Profile
bond create widget --name ProfileCard --type consumer --feature profile

bond add google_auth
```

Generated files go to `lib/features/<feature>/`: models to `data/models/`
(json_serializable, then `build_runner` runs; `--no-build-runner` skips it),
widgets to `presentation/widgets/`, and service providers to
`<name>_service_provider.dart`. `--feature` defaults to the snake_case name.

## Compatibility

| Bond CLI | Template | Flutter |
|---|---|---|
| 0.1.x | `v2.0.0` (default `--ref`) | 3.47.7+ |
| 0.0.4+3 (or 0.1.x with `--ref v1.0.0`) | `v1.0.0` (legacy) | 3.19–3.27 era |

## Local Development

To activate the Bond CLI for local development, run the following command:

```bash
dart pub global activate --source="path" . --executable="bond" --overwrite
```

**Important**: After each update to the code, you may need to delete the cached snapshot of the Bond CLI to ensure your changes are reflected. 

To delete the cached snapshot, navigate to the following path and remove the snapshot files:

```bash
.dart_tool/pub/bin/bond_cli/*.snapshot
```

This step ensures that your code changes are recognized during development.

Run the checks with:

```bash
dart analyze
dart test
```
