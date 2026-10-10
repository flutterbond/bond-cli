import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/tasks/core/tasks.dart';

import 'tasks/update_app_name_task_for_android.dart';
import 'tasks/update_application_id_task.dart';

class SetupAndroidProjectTask extends Tasks {
  final Directory projectDirectory;
  final String appName;
  final String applicationId;

  SetupAndroidProjectTask({
    required this.projectDirectory,
    required this.appName,
    required this.applicationId,
  });

  @override
  String get actionDescription => 'Set up the Android project';

  @override
  List<Task> get tasks => [
    UpdateAppNameTaskForAndroid(
      projectDirectory: projectDirectory,
      appName: appName,
    ),
    UpdateApplicationIdTask(
      projectDirectory: projectDirectory,
      applicationId: applicationId,
    ),
  ];
}
