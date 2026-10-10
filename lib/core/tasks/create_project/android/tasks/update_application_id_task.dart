import 'dart:io';

import 'package:bond_cli/core/native/android_project.dart';
import 'package:bond_cli/core/native/flutter_project.dart';
import 'package:bond_cli/core/tasks/core/task.dart';

class UpdateApplicationIdTask extends Task<void> {
  final Directory projectDirectory;
  final String applicationId;

  UpdateApplicationIdTask({
    required this.projectDirectory,
    required this.applicationId,
  });

  @override
  String get actionDescription =>
      'Update Android application ID to $applicationId';

  @override
  Future<void> execute() async {
    final android = AndroidProject(projectDirectory);
    final oldId = android.applicationId;
    android.setApplicationId(applicationId).forEach(warn);
    if (oldId != null) {
      FlutterProject(projectDirectory)
          .renameAppId(oldId: oldId, newId: applicationId, ios: false);
    }
  }
}
