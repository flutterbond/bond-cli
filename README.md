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
| `--ref` | `v2.1.0` | Template branch or tag. |
| `--[no-]pub-get` | on | Run `flutter pub get` in the new project. |

The project is cloned into `./<project_name>`, renamed (Dart package and
imports, Android application ID, namespace and Kotlin package, iOS bundle IDs,
Firebase config IDs, app names; the staging flavor keeps its `.staging`
suffix), and committed as a fresh git repository. The names and the template
version are recorded in `bond.yaml`; commit it, `bond upgrade` reads it.

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

## Upgrading a project

A project is a copy of the template, so template changes (iOS and Android
config, scripts, tooling) do not arrive with `flutter pub upgrade`. `bond
upgrade` brings them in, like `git merge` would, even though the project was
renamed:

```bash
bond upgrade --dry-run     # what would change, nothing is written
bond upgrade               # upgrade to the newest template tag, on a new branch
bond upgrade --to v2.2.0   # or to a specific tag or branch
```

It renders the template version your project was created from and the new one
with your project's names, then three-way merges the difference into your
files, on the branch `bond/upgrade-<version>`. Nothing is committed.

| Your file | Result |
|---|---|
| unchanged by you | updated, added or removed like the template |
| changed by you, and by the template | merged; real conflicts get `<<<<<<<` markers |
| deleted by you | stays deleted |
| new in the template, you already have one | the template's is written as `<file>.template` |
| icons, lockfiles, generated code, Firebase files, `project.pbxproj` | never merged line by line: updated only if you never changed them |

`pubspec.yaml` keeps your `version:`. The command needs a clean git work tree
(`--allow-dirty` overrides). Projects created before `bond.yaml` existed pass
the version they started from once: `bond upgrade --from v2.0.0`. Afterwards,
run `flutter pub upgrade` for the bond_* packages and `dart fix --apply` for
renamed APIs, resolve the conflicts, and read the template's `MIGRATION.md`.

## MCP server (Claude Code and other agents)

`bond mcp` starts an MCP server over stdio that teaches coding agents the bond_* packages of a
project, for the exact versions the project resolves, and scaffolds code the Bond way:

| Tool | What it does |
|---|---|
| `packages` | bond_* packages of the project with version, description and source |
| `package_overview` | what a package does: public libraries, README, example, latest changes |
| `api` | the public API read from the package source (filter with `symbol`, paged) |
| `migration` | migration guides, or one package's changes between two versions |
| `create_model`, `create_widget`, `create_service_provider` | generators (never overwrite files) |
| `create_project` | a new project from the flutter-bond template |
| `upgrade_template` | upgrade a project's template files to a newer version (dry run by default) |

It also serves `bond://package/{name}/{readme|changelog|example}` resources and a `bond_review`
prompt.

Install the CLI with `dart install bond_cli` (Dart 3.13 or newer). It compiles `bond` to a native
executable, so the server starts fast and writes nothing but MCP messages to stdout. Then register
it in the project's `.mcp.json` and check it with `claude mcp get bond`:

```json
{"mcpServers": {"bond": {"type": "stdio", "command": "bond", "args": ["mcp"]}}}
```

Projects created from the flutter-bond template already register it through `tool/mcp/bond.sh`,
which finds the installed `bond` even when its folder is not on PATH. Don't start the server with
`dart pub global run`: pub can print to stdout before the server starts, which breaks the
connection.

Options: `--project <dir>` (project to answer for when the client sends no roots) and
`--log-file <path>` (protocol trace). Release checklist: run `dart run tool/sync_mcp_docs.dart`
to refresh the bundled migration guides.

## Compatibility

| Bond CLI | Template | Flutter |
|---|---|---|
| 0.3.x | `v2.1.0` (default `--ref`); `bond upgrade` for later versions | 3.47.7+ |
| 0.2.x | `v2.1.0` (default `--ref`; adds the Claude Code MCP setup) | 3.47.7+ |
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
