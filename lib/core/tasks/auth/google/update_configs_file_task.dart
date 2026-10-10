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

      // Add the import statement if it doesn't exist
      if (!configsContent.contains("import 'google_auth.dart';")) {
        configsContent = "import 'google_auth.dart';\n$configsContent";
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
