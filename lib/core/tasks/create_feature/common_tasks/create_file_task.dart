import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/utils/process.dart';
import 'package:path/path.dart' as p;

/// Writes a generated Dart file below [projectDirectory] and formats it with
/// the project's own Dart SDK. Existing files are never overwritten.
class CreateFileTask extends Task<void> {
  final Directory projectDirectory;
  final String path;
  final String content;

  CreateFileTask(this.projectDirectory, this.path, this.content);

  @override
  String get actionDescription => 'Create file: $path';

  @override
  Future<void> execute() async {
    final file = File(p.join(projectDirectory.path, path));
    if (file.existsSync()) {
      throw Exception('$path already exists.');
    }
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(content);

    try {
      await runFlutterTool(projectDirectory, 'dart', ['format', path]);
    } on ProcessFailure catch (error) {
      warn('Could not format $path: $error');
    }
  }
}
