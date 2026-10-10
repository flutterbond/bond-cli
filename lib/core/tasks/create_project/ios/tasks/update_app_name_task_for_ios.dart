import 'dart:io';

import 'package:bond_cli/core/native/ios_project.dart';
import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/utils.dart';

class UpdateIOSAppNameTaskForIOS extends Task<void> {
  final Directory projectDirectory;
  final String appName;

  UpdateIOSAppNameTaskForIOS({
    required this.projectDirectory,
    required this.appName,
  });

  @override
  String get actionDescription => 'Update iOS app name to $appName';

  @override
  Future<void> execute() async {
    IosProject(projectDirectory)
        .setAppName(displayName: appName, bundleName: appName.toSnakeCase())
        .forEach(warn);
  }
}
