import 'dart:io';

import 'package:bond_cli/core/native/android_project.dart';
import 'package:bond_cli/core/tasks/core/task.dart';

class UpdateAppNameTaskForAndroid extends Task<void> {
  final Directory projectDirectory;
  final String appName;

  UpdateAppNameTaskForAndroid({
    required this.projectDirectory,
    required this.appName,
  });

  @override
  String get actionDescription => 'Update Android app name to $appName';

  @override
  Future<void> execute() async {
    AndroidProject(projectDirectory).setAppName(appName).forEach(warn);
  }
}
