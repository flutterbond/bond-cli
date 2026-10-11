import 'dart:io';

import 'package:bond_cli/core/generators/feature_paths.dart';
import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/tasks/core/tasks.dart';

import 'common_tasks/create_file_task.dart';
import 'common_tasks/run_build_runner_task.dart';

class CreateModelTasks extends Tasks {
  final Directory projectDirectory;
  final String modelName;
  final String feature;
  final String modelContent;
  final bool runBuildRunner;

  CreateModelTasks({
    required this.projectDirectory,
    required this.modelName,
    required this.feature,
    required this.modelContent,
    this.runBuildRunner = true,
  });

  @override
  String get actionDescription => 'Creating $modelName model';

  @override
  List<Task> get tasks {
    final path = FeaturePaths.model(feature, modelName);
    return [
      CreateFileTask(projectDirectory, path, modelContent),
      if (runBuildRunner)
        RunBuildRunnerTask(projectDirectory, FeaturePaths.generatedPart(path)),
    ];
  }
}
