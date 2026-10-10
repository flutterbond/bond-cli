import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/tasks/core/tasks.dart';
import 'package:bond_cli/core/tasks/create_project/flutter/tasks/format_project_task.dart';
import 'package:bond_cli/core/tasks/create_project/flutter/tasks/pub_get_task.dart';
import 'package:native_project_manipulator/platforms/flutter/flutter.dart';

import 'tasks/update_project_name_task.dart';

class SetupFlutterProjectTask extends Tasks {
  final FlutterManager flutterManager;
  final String appName;
  final String projectName;

  SetupFlutterProjectTask({
    required this.flutterManager,
    required this.appName,
    required this.projectName,
  });

  @override
  String get actionDescription => 'Setup $appName flutter project';

  @override
  List<Task> get tasks => [
        UpdateProjectNameTask(
          flutterManager: flutterManager,
          projectName: projectName,
        ),
        // FormatProjectTask(
        //   flutterManager: flutterManager,
        //   appName: appName,
        // ),
        // PubGetTask(
        //   flutterManager: flutterManager,
        //   appName: appName,
        // ),
      ];
}
