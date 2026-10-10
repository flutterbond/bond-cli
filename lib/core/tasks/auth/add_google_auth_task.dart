import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/tasks/core/tasks.dart';

import 'google/add_dependency_to_pubspec_task.dart';
import 'google/create_configuration_file_task.dart';
import 'google/integrate_ios_task.dart';
import 'google/update_configs_file_task.dart';
import 'google/update_environment_files_task.dart';

class AddGoogleAuthTask extends Tasks {
  @override
  String get actionDescription => 'Automate Google Sign-In integration.';

  @override
  List<Task> get tasks => [
    IntegrateIosTask(),
    AddDependencyToPubspecTask(),
    UpdateEnvironmentFilesTask(),
    CreateConfigurationFileTask(),
    UpdateConfigsFileTask(),
  ];
}
