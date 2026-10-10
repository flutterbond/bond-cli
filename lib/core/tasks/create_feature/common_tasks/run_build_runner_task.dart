import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/utils/process.dart';

/// Runs build_runner in the project so a new model's generated file, e.g.
/// `lib/features/user/data/models/user.g.dart`, is created.
///
/// This is a full build on purpose: with `--build-filter`, build_runner 2.16
/// treats every generated file outside the filter as stale and deletes it,
/// which breaks the project's existing models (post.g.dart, user.g.dart, ...).
class RunBuildRunnerTask extends Task<void> {
  final Directory projectDirectory;
  final String outputPath;

  RunBuildRunnerTask(this.projectDirectory, this.outputPath);

  /// Arguments passed to `dart`.
  static const arguments = ['run', 'build_runner', 'build'];

  @override
  String get actionDescription => 'Run build_runner to generate $outputPath';

  @override
  Future<void> execute() async {
    await runFlutterTool(projectDirectory, 'dart', arguments);
  }
}
