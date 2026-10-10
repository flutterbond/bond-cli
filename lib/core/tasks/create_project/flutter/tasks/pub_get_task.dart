import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';
import 'package:bond_cli/core/utils/process.dart';

class PubGetTask extends Task<void> {
  final Directory projectDirectory;

  PubGetTask({required this.projectDirectory});

  @override
  String get actionDescription => 'Run flutter pub get';

  @override
  Future<void> execute() async {
    await runFlutterTool(projectDirectory, 'flutter', ['pub', 'get']);
  }
}
