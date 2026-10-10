import 'dart:io';

import 'package:bond_cli/core/native/flutter_project.dart';
import 'package:bond_cli/core/tasks/core/task.dart';

class UpdateProjectNameTask extends Task<void> {
  final Directory projectDirectory;
  final String projectName;

  UpdateProjectNameTask({
    required this.projectDirectory,
    required this.projectName,
  });

  @override
  String get actionDescription =>
      'Rename the Dart package to $projectName and update imports';

  @override
  Future<void> execute() async {
    FlutterProject(projectDirectory).rename(projectName);
  }
}
