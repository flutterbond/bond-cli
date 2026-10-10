import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/utils/process.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// Shallow-clones [ref] of the template into [directory] and drops its git
/// history.
class ProjectCloningTask extends Task<Directory> {
  final Directory directory;
  final String templateUrl;
  final String ref;

  ProjectCloningTask({
    required this.directory,
    required this.templateUrl,
    required this.ref,
  });

  @override
  String get actionDescription => 'Clone $templateUrl ($ref)';

  @protected
  @override
  Future<Directory> execute() async {
    if (directory.existsSync()) {
      throw Exception('"${directory.path}" already exists.');
    }

    await runProcess('git', [
      'clone',
      '--quiet',
      '--depth',
      '1',
      '--branch',
      ref,
      templateCloneSource(templateUrl),
      directory.path,
    ]);

    final gitDirectory = Directory(p.join(directory.path, '.git'));
    if (gitDirectory.existsSync()) {
      gitDirectory.deleteSync(recursive: true);
    }
    return directory;
  }
}

/// Git ignores `--depth` for plain local paths, so a local template
/// directory is passed as a `file://` URL.
String templateCloneSource(String templateUrl) {
  if (!Directory(templateUrl).existsSync()) return templateUrl;
  final path = p.absolute(templateUrl);
  return Platform.isWindows ? Uri.file(path).toString() : 'file://$path';
}
