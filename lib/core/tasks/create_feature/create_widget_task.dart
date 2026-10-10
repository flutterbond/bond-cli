import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/tasks/core/tasks.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:path/path.dart' as p;

import 'common_tasks/create_file_task.dart';

class CreateWidgetTask extends Tasks {
  final Directory projectDirectory;
  final String widgetName;
  final String feature;
  final String widgetContent;

  CreateWidgetTask({
    required this.projectDirectory,
    required this.widgetName,
    required this.feature,
    required this.widgetContent,
  });

  @override
  String get actionDescription => 'Creating $widgetName widget';

  @override
  List<Task> get tasks => [
    CreateFileTask(
      projectDirectory,
      p.posix.join(
        'lib',
        'features',
        feature,
        'presentation',
        'widgets',
        '${widgetName.toSnakeCase()}.dart',
      ),
      widgetContent,
    ),
  ];
}
