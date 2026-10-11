import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Where a bond_* package comes from in a project's dependency resolution.
enum PackageSource { hosted, git, path }

/// A bond_* package as resolved by a project's `.dart_tool/package_config.json`.
class BondPackage {
  const BondPackage({
    required this.name,
    required this.version,
    required this.description,
    required this.rootDir,
    required this.source,
  });

  final String name;
  final String version;
  final String description;

  /// Absolute path of the package root (the folder with its pubspec.yaml).
  final String rootDir;
  final PackageSource source;

  String get libDir => p.join(rootDir, 'lib');

  Map<String, Object?> toJson() => {
    'name': name,
    'version': version,
    'description': description,
    'source': source.name,
    'rootDir': rootDir,
  };
}

/// The bond_* packages of one project, plus where they were resolved from.
class ResolvedBondPackages {
  const ResolvedBondPackages({
    required this.projectRoot,
    required this.packageConfigPath,
    required this.packages,
  });

  /// The folder containing `.dart_tool/` (the workspace root for pub workspaces).
  final String projectRoot;
  final String packageConfigPath;
  final List<BondPackage> packages;

  BondPackage? find(String name) {
    for (final package in packages) {
      if (package.name == name) return package;
    }
    return null;
  }

  Map<String, Object?> resolvedFrom() => {
    'projectRoot': projectRoot,
    'packageConfig': packageConfigPath,
  };
}

/// Thrown when a project has no `.dart_tool/package_config.json` yet.
class PackageConfigNotFound implements Exception {
  PackageConfigNotFound(this.projectDir);

  final String projectDir;

  @override
  String toString() =>
      'No .dart_tool/package_config.json found for $projectDir. '
      'Run `flutter pub get` (or `dart pub get`) in the project first.';
}

/// Finds the bond_* packages a project actually depends on, at the versions it
/// resolved: hosted packages in the pub cache for apps, path packages for the
/// bond-core workspace or path overrides.
class BondPackageLocator {
  BondPackageLocator({String? pubCacheDir})
    : _pubCacheDir = pubCacheDir ?? defaultPubCacheDir();

  final String _pubCacheDir;
  final _cache = <String, (DateTime, ResolvedBondPackages)>{};

  /// Packages that start with `bond_` but are not libraries an app uses.
  static const _ignored = {'bond_cli', 'bond_core_workspace'};

  static String defaultPubCacheDir() {
    final env = Platform.environment;
    final fromEnv = env['PUB_CACHE'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isWindows) {
      return p.join(env['LOCALAPPDATA'] ?? '', 'Pub', 'Cache');
    }
    return p.join(env['HOME'] ?? '', '.pub-cache');
  }

  /// The package config that applies to [projectDir], searching upwards so a
  /// pub workspace member finds the workspace root's config.
  static File? findPackageConfigFile(Directory projectDir) {
    var dir = Directory(p.normalize(projectDir.absolute.path));
    while (true) {
      final file = File(p.join(dir.path, '.dart_tool', 'package_config.json'));
      if (file.existsSync()) return file;
      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }

  /// Resolves the bond_* packages of [projectDir]; cached until the package
  /// config changes.
  Future<ResolvedBondPackages> locate(Directory projectDir) async {
    final file = findPackageConfigFile(projectDir);
    if (file == null) throw PackageConfigNotFound(projectDir.absolute.path);

    final modified = file.lastModifiedSync();
    final cached = _cache[file.path];
    if (cached != null && cached.$1 == modified) return cached.$2;

    final config = await loadPackageConfig(file);
    final packages = <BondPackage>[];
    for (final package in config.packages) {
      if (!package.name.startsWith('bond_') ||
          _ignored.contains(package.name)) {
        continue;
      }
      final rootDir = p.normalize(package.root.toFilePath());
      final pubspec = _readPubspec(rootDir);
      packages.add(
        BondPackage(
          name: package.name,
          version: pubspec?['version']?.toString() ?? 'unknown',
          description: (pubspec?['description'] ?? '').toString().trim(),
          rootDir: rootDir,
          source: _sourceOf(rootDir),
        ),
      );
    }
    packages.sort((a, b) => a.name.compareTo(b.name));

    final result = ResolvedBondPackages(
      projectRoot: p.dirname(p.dirname(file.path)),
      packageConfigPath: file.path,
      packages: packages,
    );
    _cache[file.path] = (modified, result);
    return result;
  }

  PackageSource _sourceOf(String rootDir) {
    if (p.isWithin(p.join(_pubCacheDir, 'hosted'), rootDir)) {
      return PackageSource.hosted;
    }
    if (p.isWithin(p.join(_pubCacheDir, 'git'), rootDir)) {
      return PackageSource.git;
    }
    return PackageSource.path;
  }

  static YamlMap? _readPubspec(String rootDir) {
    try {
      final yaml = loadYaml(
        File(p.join(rootDir, 'pubspec.yaml')).readAsStringSync(),
      );
      return yaml is YamlMap ? yaml : null;
    } on Exception {
      return null;
    }
  }
}
