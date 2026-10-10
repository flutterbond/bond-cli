import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/utils.dart';

class RunBuildRunnerTask extends Task<void> {
  final String directoryPath;
  final String modelName;

  RunBuildRunnerTask(this.directoryPath, this.modelName);

  @override
  String get actionDescription =>
      'Run build runner to generate the $modelName.g.dart file.';

  @override
  Future<void> execute() async {
    final result = await Process.run('dart', [
      'run',
      'build_runner',
      'build',
      '--delete-conflicting-outputs',
      '--build-filter="$directoryPath*.dart"'
    ]);
    logger.detail('${result.stdout}');
    if (result.exitCode != 0) {
      throw Exception('build_runner failed: ${result.stderr}');
    }
  }
}
