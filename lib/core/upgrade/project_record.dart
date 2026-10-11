import 'dart:convert';
import 'dart:io';

import 'package:bond_cli/core/native/android_project.dart';
import 'package:bond_cli/core/native/flutter_project.dart';
import 'package:bond_cli/core/native/ios_project.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The names `bond create project` applied to the template: what `bond
/// upgrade` re-applies to a newer template version.
class ProjectIdentity {
  const ProjectIdentity({
    required this.name,
    required this.appName,
    required this.bundleId,
    required this.applicationId,
  });

  /// Dart package name (snake_case).
  final String name;

  /// Name on the home screen.
  final String appName;

  /// iOS bundle ID.
  final String bundleId;

  /// Android application ID.
  final String applicationId;

  /// Reads the identity from the project's own files, for projects without a
  /// [ProjectRecord]. Warnings are returned for values that disagree between
  /// iOS and Android.
  static ({ProjectIdentity identity, List<String> warnings}) detect(
    Directory project,
  ) {
    final warnings = <String>[];
    final flutter = FlutterProject(project);
    final ios = IosProject(project);
    final android = AndroidProject(project);

    final name = _read('the pubspec name', () => flutter.name);
    final bundleId = _read(
      'the iOS bundle ID (PRODUCT_BUNDLE_IDENTIFIER)',
      () => ios.bundleId,
    );
    final applicationId = _read(
      'the Android applicationId',
      () => android.applicationId,
    );
    final iosName = _tryRead(() => ios.displayName);
    final androidName = _tryRead(() => android.appName);
    final appName = iosName ?? androidName;
    if (appName == null) {
      throw const FormatException(
        'Could not read the app name (CFBundleDisplayName in '
        'ios/Runner/Info.plist or app_name in android strings.xml).',
      );
    }
    if (iosName != null && androidName != null && iosName != androidName) {
      warnings.add(
        'The iOS app name "$iosName" differs from the Android one '
        '"$androidName"; using "$iosName".',
      );
    }
    return (
      identity: ProjectIdentity(
        name: name,
        appName: appName,
        bundleId: bundleId,
        applicationId: applicationId,
      ),
      warnings: warnings,
    );
  }

  static String _read(String what, String? Function() read) {
    final value = _tryRead(read);
    if (value == null) throw FormatException('Could not read $what.');
    return value;
  }

  static String? _tryRead(String? Function() read) {
    try {
      return read();
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }
}

/// `bond.yaml` at the project root: which template (URL and ref) the project
/// was created from, and the names applied to it. Written by `bond create
/// project` and updated by `bond upgrade`; keep it in git.
class ProjectRecord {
  const ProjectRecord({
    required this.templateUrl,
    required this.ref,
    required this.identity,
  });

  static const fileName = 'bond.yaml';

  final String templateUrl;
  final String ref;
  final ProjectIdentity identity;

  ProjectRecord withRef(String newRef) =>
      ProjectRecord(templateUrl: templateUrl, ref: newRef, identity: identity);

  /// The record of [project], or null when it has none.
  static ProjectRecord? read(Directory project) {
    final file = File(p.join(project.path, fileName));
    if (!file.existsSync()) return null;
    return parse(file.readAsStringSync());
  }

  static ProjectRecord parse(String text) {
    final Object? yaml;
    try {
      yaml = loadYaml(text);
    } on YamlException catch (error) {
      throw FormatException('$fileName is not valid YAML: ${error.message}');
    }
    final template = _section(yaml, 'template');
    final project = _section(yaml, 'project');
    return ProjectRecord(
      templateUrl: _string(template, 'template.url', 'url'),
      ref: _string(template, 'template.ref', 'ref'),
      identity: ProjectIdentity(
        name: _string(project, 'project.name', 'name'),
        appName: _string(project, 'project.appName', 'appName'),
        bundleId: _string(project, 'project.bundleId', 'bundleId'),
        applicationId: _string(
          project,
          'project.applicationId',
          'applicationId',
        ),
      ),
    );
  }

  void write(Directory project) =>
      File(p.join(project.path, fileName)).writeAsStringSync(toYaml());

  String toYaml() =>
      '''
# Written by bond_cli; `bond upgrade` reads it. Keep it in git.
template:
  url: ${_scalar(templateUrl)}
  ref: ${_scalar(ref)}
project:
  name: ${_scalar(identity.name)}
  appName: ${_scalar(identity.appName)}
  bundleId: ${_scalar(identity.bundleId)}
  applicationId: ${_scalar(identity.applicationId)}
''';

  static YamlMap _section(Object? yaml, String key) {
    final section = yaml is YamlMap ? yaml[key] : null;
    if (section is! YamlMap) {
      throw FormatException('$fileName has no `$key:` section.');
    }
    return section;
  }

  static String _string(YamlMap section, String path, String key) {
    final value = section[key];
    if (value == null || '$value'.isEmpty) {
      throw FormatException('$fileName is missing `$path`.');
    }
    return '$value';
  }

  /// Plain YAML for simple values, a JSON (double-quoted) string otherwise.
  static String _scalar(String value) {
    final plain =
        RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.:/@+-]*$').hasMatch(value) &&
        num.tryParse(value) == null &&
        !const {
          'true',
          'false',
          'null',
          'yes',
          'no',
          'on',
          'off',
        }.contains(value.toLowerCase());
    return plain ? value : jsonEncode(value);
  }
}
