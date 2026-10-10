import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/tasks/core/tasks.dart';

import 'tasks/update_app_name_task_for_ios.dart';
import 'tasks/update_bundle_id_task.dart';

class SetupIosProjectTask extends Tasks {
  final Directory projectDirectory;
  final String appName;
  final String bundleId;

  SetupIosProjectTask({
    required this.projectDirectory,
    required this.appName,
    required this.bundleId,
  });

  @override
  String get actionDescription => 'Set up the iOS project';

  @override
  List<Task> get tasks => [
    UpdateBundleIdTask(projectDirectory: projectDirectory, bundleId: bundleId),
    UpdateIOSAppNameTaskForIOS(
      projectDirectory: projectDirectory,
      appName: appName,
    ),
  ];
}
