import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:bond_cli/core/tasks.dart';
import 'package:bond_cli/core/tasks/create_project/android/tasks/update_app_name_task_for_android.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/validators.dart';
import 'package:native_project_manipulator/platforms/android/android.dart';
import 'package:native_project_manipulator/platforms/ios/ios_manager.dart';

class UpdateAppNameCommand extends Command<void> with InputResolver {
  @override
  String get name => 'app_name';

  @override
  String get description => 'Update the app name for iOS and Android.';

  UpdateAppNameCommand() {
    argParser.addOption('name', abbr: 'n', help: 'Specify the new app name.');
  }

  @override
  Future<void> run() async {
    final appName = resolveInput(
      'name',
      prompt: 'Enter New App Name:',
      validators: [
        NonEmptyValidator(),
      ],
    );

    final projectDirectoryPath = Directory.current.path;

    await UpdateIOSAppNameTaskForIOS(
      iosManager: IosManager(Directory('$projectDirectoryPath/ios')),
      appName: appName,
    ).execute();

    await UpdateAppNameTaskForAndroid(
      androidManager:
          AndroidManager(Directory('$projectDirectoryPath/android')),
      appName: appName,
    ).execute();
  }
}
