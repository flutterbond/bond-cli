import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:bond_cli/core/tasks.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/validators.dart';
import 'package:native_project_manipulator/platforms/android/android_manager.dart';
import 'package:native_project_manipulator/platforms/flutter/flutter_manager.dart';
import 'package:native_project_manipulator/platforms/ios/ios_manager.dart';

class CreateProjectCommand extends Command<void> with InputResolver {
  @override
  String get description => 'Creates a new Flutter Bond project';

  @override
  String get name => 'project';

  CreateProjectCommand() {
    argParser.addOption(
      'projectName',
      help: 'Name of the new project',
      valueHelp: 'my_dream_project',
    );
    argParser.addOption(
      'bundleId',
      help: 'IOS Bundle Id of the new project',
      valueHelp: 'sa.bond.com',
    );
    argParser.addOption(
      'applicationId',
      help: 'Android Application Id of the new project',
      valueHelp: 'sa.bond.com',
    );
  }

  @override
  Future<void> run() async {
    final projectName = resolveInput(
      'projectName',
      prompt: 'Enter Project Name:',
      defaultValue: 'my_dream_project',
      validators: [
        ProjectNameValidator(),
      ],
    );

    final iosBundleId = resolveInput(
      'bundleId',
      prompt: 'Enter IOS Bundle Id:',
      defaultValue: 'sa.bond.com',
      validators: [IosBundleIdValidator()],
    );

    final androidApplicationId = resolveInput(
      'applicationId',
      prompt: 'Enter Android Application Id:',
      defaultValue: 'sa.bond.com',
      validators: [AndroidAppIdValidator()],
    );

    final appName = projectName.replaceAll(' ', '_').toLowerCase();

    final projectPath = '${Directory.current.path}/$projectName';
    logger.info('Creating a "$appName" project at $projectPath');

    final projectDirectory = await ProjectCloningTask(
      projectName: projectName,
    ).run();

    if (Platform.isMacOS) {
      await SetupIosProjectTask(
        iosManager: IosManager(
          Directory(
            '${projectDirectory.path}/ios',
          ),
        ),
        bundleId: iosBundleId,
        appName: appName,
      ).run();
    } else {
      logger.warn('skip setup ios ios project for non mac os.');
    }

    await SetupAndroidProjectTask(
      androidManager: AndroidManager(
        Directory('${projectDirectory.path}/android'),
      ),
      appName: appName,
      applicationId: androidApplicationId,
    ).run();

    await SetupFlutterProjectTask(
      flutterManager: FlutterManager(
        projectDirectory,
        printToConsole: false,
      ),
      appName: appName,
      projectName: projectName,
    ).run();
  }
}
