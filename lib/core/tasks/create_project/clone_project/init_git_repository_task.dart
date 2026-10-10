import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/utils/process.dart';

/// Starts a fresh git history for the generated project.
class InitGitRepositoryTask extends Task<void> {
  final Directory directory;
  final String message;

  InitGitRepositoryTask({required this.directory, required this.message});

  @override
  String get actionDescription => 'Create the initial git commit';

  @override
  Future<void> execute() async {
    final path = directory.path;
    await runProcess('git', ['init', '--quiet'], workingDirectory: path);
    await runProcess('git', ['add', '--all'], workingDirectory: path);
    await runProcess('git', [
      'commit',
      '--quiet',
      '--message',
      message,
    ], workingDirectory: path);
  }
}
