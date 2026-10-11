import 'dart:io';

import 'package:bond_cli/core/tasks.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/utils/process.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'project_record.dart';
import 'template_files.dart';

/// Clones the template [ref] into [directory] and applies [identity] to it:
/// the part of `bond create project` that does not need git history, pub or
/// a terminal. [directory] must not exist.
Future<void> renderTemplate({
  required Directory directory,
  required String templateUrl,
  required String ref,
  required ProjectIdentity identity,
  bool pubGet = false,
}) async {
  await ProjectCloningTask(
    directory: directory,
    templateUrl: templateUrl,
    ref: ref,
  ).run();
  for (final name in templateOnlyFiles) {
    final file = File(p.join(directory.path, name));
    if (file.existsSync()) file.deleteSync();
  }
  await SetupAndroidProjectTask(
    projectDirectory: directory,
    appName: identity.appName,
    applicationId: identity.applicationId,
  ).run();
  await SetupIosProjectTask(
    projectDirectory: directory,
    appName: identity.appName,
    bundleId: identity.bundleId,
  ).run();
  await SetupFlutterProjectTask(
    projectDirectory: directory,
    projectName: identity.name,
    pubGet: pubGet,
  ).run();
}

/// A template version rendered with a project's names, in a temporary folder.
class TemplateSnapshot {
  TemplateSnapshot._(this._temp, this.directory, this.ref);

  final Directory _temp;
  final Directory directory;
  final String ref;

  /// Renders [ref] with [identity]. The tasks print spinners, so the logger
  /// is silenced meanwhile. Call [dispose] when done.
  static Future<TemplateSnapshot> render({
    required String templateUrl,
    required String ref,
    required ProjectIdentity identity,
  }) async {
    final temp = Directory.systemTemp.createTempSync('bond_upgrade_');
    final directory = Directory(p.join(temp.path, 'template'));
    final level = logger.level;
    logger.level = Level.quiet;
    try {
      await renderTemplate(
        directory: directory,
        templateUrl: templateUrl,
        ref: ref,
        identity: identity,
      );
    } catch (_) {
      temp.deleteSync(recursive: true);
      rethrow;
    } finally {
      logger.level = level;
    }
    return TemplateSnapshot._(temp, directory, ref);
  }

  /// Files of the snapshot by their path relative to the project root, with
  /// `/` separators.
  Map<String, File> get files => {
    for (final entity in directory.listSync(
      recursive: true,
      followLinks: false,
    ))
      if (entity is File)
        p.posix.joinAll(p.split(p.relative(entity.path, from: directory.path))):
            entity,
  };

  void dispose() {
    if (_temp.existsSync()) _temp.deleteSync(recursive: true);
  }
}

/// The newest release tag (`v1.2.3`, `1.2`, `v2-beta`...) of the template,
/// ignoring pre-releases unless there is nothing else.
Future<String> latestTemplateRef(String templateUrl) async {
  final result = await runProcess('git', [
    'ls-remote',
    '--tags',
    '--refs',
    templateCloneSource(templateUrl),
  ]);
  final versions = <(Version, String)>[];
  for (final line in '${result.stdout}'.split('\n')) {
    final tag = line.split('refs/tags/').last.trim();
    if (!line.contains('refs/tags/')) continue;
    final version = _parseTag(tag);
    if (version != null) versions.add((version, tag));
  }
  if (versions.isEmpty) {
    throw Exception('$templateUrl has no version tags (v1.2.3).');
  }
  final stable = versions.where((v) => !v.$1.isPreRelease).toList();
  final candidates = stable.isEmpty ? versions : stable;
  candidates.sort((a, b) => a.$1.compareTo(b.$1));
  return candidates.last.$2;
}

/// `v2.1.0`, `2.1` or `v3-beta` as a [Version]; null for any other tag.
Version? _parseTag(String tag) {
  final match = RegExp(r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?([-+].*)?$')
      .firstMatch(tag);
  if (match == null) return null;
  try {
    return Version.parse(
      '${match[1]}.${match[2] ?? 0}.${match[3] ?? 0}${match[4] ?? ''}',
    );
  } on FormatException {
    return null;
  }
}
