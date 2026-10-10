import 'dart:io';

import 'package:bond_cli/core/native/flutter_project.dart';
import 'package:bond_cli/core/native/ios_project.dart';
import 'package:bond_cli/core/tasks/core/task.dart';

/// Renames the bundle ID of every build configuration; Staging keeps its
/// `.staging` suffix.
class UpdateBundleIdTask extends Task<void> {
  final Directory projectDirectory;
  final String bundleId;

  UpdateBundleIdTask({required this.projectDirectory, required this.bundleId});

  @override
  String get actionDescription => 'Update iOS bundle ID to $bundleId';

  @override
  Future<void> execute() async {
    final ios = IosProject(projectDirectory);
    final oldId = ios.bundleId;
    ios.setBundleId(bundleId).forEach(warn);
    if (oldId != null) {
      FlutterProject(projectDirectory)
          .renameAppId(oldId: oldId, newId: bundleId, ios: true);
    }
  }
}
