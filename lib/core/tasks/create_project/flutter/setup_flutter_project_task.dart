import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/tasks/core/tasks.dart';

import 'tasks/pub_get_task.dart';
import 'tasks/update_project_name_task.dart';

class SetupFlutterProjectTask extends Tasks {
  final Directory projectDirectory;
  final String projectName;
  final bool pubGet;

  SetupFlutterProjectTask({
    required this.projectDirectory,
    required this.projectName,
    this.pubGet = true,
  });

  @override
  String get actionDescription => 'Set up the $projectName Flutter project';

  // `dart format` is intentionally not run: renaming `package:` URIs only
  // touches directives, which the formatter never re-wraps, while formatting
  // the whole tree would rewrite generated files for no gain.
  @override
  List<Task> get tasks => [
    UpdateProjectNameTask(
      projectDirectory: projectDirectory,
      projectName: projectName,
    ),
    if (pubGet) PubGetTask(projectDirectory: projectDirectory),
  ];
}
