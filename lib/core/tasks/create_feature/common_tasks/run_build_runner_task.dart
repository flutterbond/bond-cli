import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/utils/process.dart';

/// Runs build_runner for a single generated output, e.g.
/// `lib/features/user/data/models/user.g.dart`.
class RunBuildRunnerTask extends Task<void> {
  final Directory projectDirectory;
  final String outputPath;

  RunBuildRunnerTask(this.projectDirectory, this.outputPath);

  @override
  String get actionDescription => 'Run build_runner to generate $outputPath';

  @override
  Future<void> execute() async {
    // The filter is passed as its own argument, not shell-quoted: quotes
    // would become part of the path and match nothing.
    await runFlutterTool(projectDirectory, 'dart', [
      'run',
      'build_runner',
      'build',
      '--delete-conflicting-outputs',
      '--build-filter=$outputPath',
    ]);
  }
}
