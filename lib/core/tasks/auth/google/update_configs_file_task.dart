import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';

class UpdateConfigsFileTask extends Task {
  UpdateConfigsFileTask();

  @override
  String get actionDescription => 'Update configs.dart file with new configs.';

  @override
  Future<void> execute() async {
    // Update configs.dart file
    final configsFilePath = 'lib/config/configs.dart';
    final configsFile = File(configsFilePath);
    if (configsFile.existsSync()) {
      var configsContent = await configsFile.readAsString();

      // Add the import after the existing ones if it doesn't exist.
      const importLine = "import 'google_auth.dart';";
      if (!configsContent.contains(importLine)) {
        final lastImport = RegExp(
          r'^import .*;\n',
          multiLine: true,
        ).allMatches(configsContent).lastOrNull;
        final at = lastImport?.end ?? 0;
        configsContent = configsContent.replaceRange(at, at, '$importLine\n');
      }
      if (!configsContent.contains('...googleAuthConfigs')) {
        configsContent = configsContent.replaceFirst(
          'final configs = {',
          'final configs = {\n  ...googleAuthConfigs,',
        );
        await configsFile.writeAsString(configsContent);
      } else {
        warn('configs.dart already contains googleAuthConfigs.');
      }
    } else {
      throw Exception('lib/config/configs.dart not found.');
    }
  }
}
