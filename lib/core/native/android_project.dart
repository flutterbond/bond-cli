import 'dart:io';

import 'package:path/path.dart' as p;

import 'text_edits.dart';

/// Matches `key = "value"` (Kotlin DSL) and `key "value"` (Groovy).
RegExp _gradleProperty(String key) =>
    RegExp('\\b$key(\\s*=\\s*|\\s+)(["\'])([^"\'\\n]*)\\2');

/// Reads the first `applicationId`, `namespace`, ... value of a Gradle file.
String? readGradleProperty(String gradle, String key) =>
    _gradleProperty(key).firstMatch(gradle)?.group(3);

/// Sets [key] to [value]. Further occurrences, e.g. a per-flavor
/// `applicationId`, keep their suffix relative to the first one.
String setGradleProperty(String gradle, String key, String value) {
  final oldValue = readGradleProperty(gradle, key);
  if (oldValue == null) {
    throw FormatException('No `$key` found in the Gradle build file.');
  }
  return gradle.replaceAllMapped(
    _gradleProperty(key),
    (m) => '$key${m[1]}${m[2]}${renameIdPrefix(m[3]!, oldValue, value)}${m[2]}',
  );
}

RegExp _stringResource(String name) => RegExp(
  '(<string\\s+name="${RegExp.escape(name)}"[^>]*>)([\\s\\S]*?)(</string>)',
);

/// Reads the raw (escaped) value of a `<string name="...">` resource.
String? readStringResource(String xml, String name) =>
    _stringResource(name).firstMatch(xml)?.group(2);

/// Sets an already escaped `<string name="...">` value, adding the resource
/// when it is missing.
String setStringResource(String xml, String name, String escapedValue) {
  final pattern = _stringResource(name);
  if (pattern.hasMatch(xml)) {
    return xml.replaceFirstMapped(
      pattern,
      (m) => '${m[1]}$escapedValue${m[3]}',
    );
  }
  final closing = xml.lastIndexOf('</resources>');
  if (closing < 0) throw const FormatException('No <resources> element.');
  return xml.replaceRange(
    closing,
    closing,
    '    <string name="$name">$escapedValue</string>\n',
  );
}

/// Escapes text for an Android string resource.
String escapeAndroidString(String value) {
  final escaped = xmlEscape(value)
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('"', r'\"');
  return escaped.startsWith(RegExp('[@?]')) ? '\\$escaped' : escaped;
}

final _resValueAppName = RegExp(
  r'''(resValue\s*\(?\s*["']string["']\s*,\s*["']app_name["']\s*,\s*)(["'])([^"'\n]*)\2''',
);

/// Renames the legacy `resValue "string", "app_name", "..."` entries (one per
/// flavor) of a pre-2.0 template, keeping flavor suffixes.
String setResValueAppName(String gradle, String escapedName) {
  final values = _resValueAppName.allMatches(gradle).map((m) => m[3]!).toList();
  if (values.isEmpty) return gradle;
  final base = _shortest(values);
  return gradle.replaceAllMapped(
    _resValueAppName,
    (m) => '${m[1]}${m[2]}${renameWithSuffix(m[3]!, base, escapedName)}${m[2]}',
  );
}

/// Removes the `package` attribute of the `<manifest>` element; AGP 8+ takes
/// the namespace from the Gradle file instead.
String removeManifestPackage(String manifest) => manifest.replaceFirstMapped(
  RegExp(r'<manifest\b[^>]*>'),
  (m) => m[0]!.replaceFirst(RegExp(r'\s+package="[^"]*"'), ''),
);

/// Rewrites fully qualified `android:name` class references.
String renameManifestClassNames(
  String manifest,
  String oldPackage,
  String newPackage,
) => manifest.replaceAllMapped(
  RegExp('android:name="${RegExp.escape(oldPackage)}(\\.[^"]*)"'),
  (m) => 'android:name="$newPackage${m[1]}"',
);

/// Rewrites `package` and `import` lines of a Kotlin or Java source file.
String renameSourcePackage(
  String source,
  String oldPackage,
  String newPackage,
) => source.replaceAllMapped(
  RegExp(
    '^(\\s*(?:package|import)\\s+)${RegExp.escape(oldPackage)}(?=[.;\\s]|\$)',
    multiLine: true,
  ),
  (m) => '${m[1]}$newPackage',
);

/// Renames every `package_name` of a `google-services.json` that is [oldId]
/// or a child of it, e.g. `ps.app.bond.staging` -> `com.acme.staging`.
String renameGoogleServicesPackages(String json, String oldId, String newId) =>
    json.replaceAllMapped(
      RegExp(r'("package_name"\s*:\s*")([^"]*)(")'),
      (m) => '${m[1]}${renameIdPrefix(m[2]!, oldId, newId)}${m[3]}',
    );

/// Moves the source directory of [oldPackage] below [sourceRoot] (e.g.
/// `src/main/kotlin`) to [newPackage], keeping segment order, and rewrites
/// the `package`/`import` lines of the moved files. Directories left empty
/// are removed.
void moveSourcePackage(
  Directory sourceRoot,
  String oldPackage,
  String newPackage,
) {
  if (oldPackage == newPackage) return;
  final oldDir = Directory(
    p.joinAll([sourceRoot.path, ...oldPackage.split('.')]),
  );
  final newDir = Directory(
    p.joinAll([sourceRoot.path, ...newPackage.split('.')]),
  );
  if (!oldDir.existsSync()) {
    throw FileSystemException('Package directory not found', oldDir.path);
  }

  // Park the package first: the new path may be inside the old one or one of
  // its parents.
  final parked = oldDir.renameSync(
    p.join(sourceRoot.path, '.bond_${DateTime.now().microsecondsSinceEpoch}'),
  );
  _deleteEmptyDirectories(oldDir.parent, until: sourceRoot);

  if (!newDir.existsSync()) {
    newDir.parent.createSync(recursive: true);
    parked.renameSync(newDir.path);
  } else {
    for (final entity in parked.listSync()) {
      final target = p.join(newDir.path, p.basename(entity.path));
      if (FileSystemEntity.typeSync(target) != FileSystemEntityType.notFound) {
        throw FileSystemException('Cannot move package, target exists', target);
      }
      entity.renameSync(target);
    }
    parked.deleteSync();
  }

  for (final file in listFiles(newDir, extensions: ['.kt', '.java'])) {
    editFile(file, (c) => renameSourcePackage(c, oldPackage, newPackage));
  }
}

void _deleteEmptyDirectories(Directory directory, {required Directory until}) {
  var current = directory;
  while (p.isWithin(until.path, current.path) &&
      current.existsSync() &&
      current.listSync().isEmpty) {
    current.deleteSync();
    current = current.parent;
  }
}

String _shortest(List<String> values) =>
    values.reduce((a, b) => b.length < a.length ? b : a);

/// The `android/` part of a Flutter project.
class AndroidProject {
  final Directory root;

  /// [root] is the Flutter project root (the folder holding `android/`).
  AndroidProject(this.root);

  Directory get appDirectory => Directory(p.join(root.path, 'android', 'app'));

  /// `app/build.gradle.kts`, or the Groovy `app/build.gradle` of older
  /// templates.
  File get buildFile {
    final kts = File(p.join(appDirectory.path, 'build.gradle.kts'));
    final groovy = File(p.join(appDirectory.path, 'build.gradle'));
    return !kts.existsSync() && groovy.existsSync() ? groovy : kts;
  }

  String? get applicationId =>
      readGradleProperty(buildFile.readAsStringSync(), 'applicationId');

  /// The launcher label without flavor suffixes (the shortest `app_name` of
  /// the `strings.xml` files), or null when no string resource defines it.
  String? get appName {
    final values = [
      for (final file in _stringsFiles)
        ?readStringResource(file.readAsStringSync(), 'app_name'),
    ];
    return values.isEmpty ? null : unescapeAndroidString(_shortest(values));
  }

  Iterable<File> get _stringsFiles => [
    for (final sourceSet in _sourceSets)
      File(p.join(sourceSet.path, 'res', 'values', 'strings.xml')),
  ].where((file) => file.existsSync());

  /// Source sets such as `main`, `debug`, `production` and `staging`.
  List<Directory> get _sourceSets {
    final src = Directory(p.join(appDirectory.path, 'src'));
    if (!src.existsSync()) return const [];
    return src.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  /// Sets `applicationId` and `namespace`, renames every `package_name` in
  /// the `google-services.json` files, moves the Kotlin package of
  /// `MainActivity` and drops manifest `package` attributes.
  ///
  /// Returns warnings for parts that could not be updated.
  List<String> setApplicationId(String newId) {
    final warnings = <String>[];
    final gradle = buildFile.readAsStringSync();
    final oldId = readGradleProperty(gradle, 'applicationId');
    if (oldId == null) {
      throw FormatException('No applicationId found in ${buildFile.path}.');
    }

    if (oldId == newId) return warnings;

    var updated = setGradleProperty(gradle, 'applicationId', newId);
    if (readGradleProperty(updated, 'namespace') != null) {
      updated = setGradleProperty(updated, 'namespace', newId);
    }
    buildFile.writeAsStringSync(updated);

    final googleServices = [
      File(p.join(appDirectory.path, 'google-services.json')),
      for (final sourceSet in _sourceSets)
        File(p.join(sourceSet.path, 'google-services.json')),
    ].where((file) => file.existsSync());
    for (final file in googleServices) {
      final renamed = editFile(
        file,
        (c) => renameGoogleServicesPackages(c, oldId, newId),
      );
      if (!renamed) {
        warnings.add(
          '${p.relative(file.path, from: root.path)} has no package_name '
          'under $oldId; download it again from the Firebase console.',
        );
      }
    }

    final oldPackage = _moveMainActivityPackage(newId);
    if (oldPackage == null) {
      warnings.add('MainActivity not found; move its package to $newId.');
    }

    for (final sourceSet in _sourceSets) {
      final manifest = File(p.join(sourceSet.path, 'AndroidManifest.xml'));
      if (!manifest.existsSync()) continue;
      editFile(
        manifest,
        (c) => renameManifestClassNames(
          removeManifestPackage(c),
          oldPackage ?? oldId,
          newId,
        ),
      );
    }
    return warnings;
  }

  /// Moves the package holding `MainActivity` to [newPackage] and returns
  /// the old package, or `null` when `MainActivity` cannot be found.
  String? _moveMainActivityPackage(String newPackage) {
    for (final language in ['kotlin', 'java']) {
      final sourceRoot = Directory(
        p.join(appDirectory.path, 'src', 'main', language),
      );
      final mainActivity = listFiles(sourceRoot, extensions: ['.kt', '.java'])
          .where(
            (file) => p.basenameWithoutExtension(file.path) == 'MainActivity',
          )
          .firstOrNull;
      if (mainActivity == null) continue;

      final oldPackage = RegExp(
        r'^\s*package\s+([\w.]+)',
        multiLine: true,
      ).firstMatch(mainActivity.readAsStringSync())?.group(1);
      if (oldPackage == null) return null;
      moveSourcePackage(sourceRoot, oldPackage, newPackage);
      return oldPackage;
    }
    return null;
  }

  /// Sets the launcher label in every `res/values/strings.xml` that defines
  /// `app_name` (one per flavor), keeping flavor suffixes such as
  /// " Staging". Falls back to the legacy Gradle `resValue` entries.
  ///
  /// Returns warnings for parts that could not be updated.
  List<String> setAppName(String appName) {
    final escaped = escapeAndroidString(appName);
    final resources = _stringsFiles.where(
      (file) => readStringResource(file.readAsStringSync(), 'app_name') != null,
    );

    if (resources.isNotEmpty) {
      final base = _shortest([
        for (final file in resources)
          readStringResource(file.readAsStringSync(), 'app_name')!,
      ]);
      for (final file in resources) {
        editFile(file, (xml) {
          final value = readStringResource(xml, 'app_name')!;
          return setStringResource(
            xml,
            'app_name',
            renameWithSuffix(value, base, escaped),
          );
        });
      }
      return const [];
    }

    if (editFile(buildFile, (gradle) => setResValueAppName(gradle, escaped))) {
      return const [];
    }
    return [
      'No app_name string resource found; set android:label in '
          'AndroidManifest.xml to "$appName".',
    ];
  }
}
