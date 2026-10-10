import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/tasks/core/tasks.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:path/path.dart' as p;

import 'common_tasks/create_file_task.dart';

class CreateServiceProviderTask extends Tasks {
  final Directory projectDirectory;
  final String serviceProviderName;
  final String feature;
  final String serviceProviderContent;

  CreateServiceProviderTask({
    required this.projectDirectory,
    required this.serviceProviderName,
    required this.feature,
    required this.serviceProviderContent,
  });

  @override
  String get actionDescription => 'Creating $serviceProviderName';

  @override
  List<Task> get tasks => [
    CreateFileTask(
      projectDirectory,
      p.posix.join(
        'lib',
        'features',
        feature,
        '${serviceProviderName.toSnakeCase()}.dart',
      ),
      serviceProviderContent,
    ),
  ];
}
