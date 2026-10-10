import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:bond_cli/core/tasks.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/validators.dart';
import 'package:path/path.dart' as p;

class CreateProjectCommand extends Command<void> with InputResolver {
  static const defaultTemplateUrl =
      'https://github.com/flutterbond/flutter-bond.git';
  static const defaultRef = 'v2.0.0';

  @override
  String get description => 'Creates a new Flutter Bond project';

  @override
  String get name => 'project';

  CreateProjectCommand() {
    argParser
      ..addOption(
        'projectName',
        aliases: ['project-name'],
        help:
            'Name of the new project; also the Dart package and folder '
            'name (converted to snake_case).',
        valueHelp: 'my_dream_project',
      )
      ..addOption(
        'appName',
        aliases: ['app-name'],
        help:
            'App name shown on the home screen. Defaults to the project '
            'name in Title Case.',
        valueHelp: 'My Dream Project',
      )
      ..addOption(
        'bundleId',
        aliases: ['bundle-id'],
        help: 'iOS bundle ID of the new project (Staging adds ".staging").',
        valueHelp: 'sa.bond.com',
      )
      ..addOption(
        'applicationId',
        aliases: ['application-id'],
        help:
            'Android application ID of the new project; also the Kotlin '
            'package (staging adds ".staging").',
        valueHelp: 'sa.bond.com',
      )
      ..addOption(
        'template-url',
        help: 'Git URL or local path of the flutter-bond template.',
        defaultsTo: defaultTemplateUrl,
      )
      ..addOption(
        'ref',
        help: 'Template branch or tag to clone.',
        defaultsTo: defaultRef,
      )
      ..addFlag(
        'pub-get',
        help: 'Run `flutter pub get` in the new project.',
        defaultsTo: true,
      );
  }

  @override
  Future<void> run() async {
    final rawProjectName = resolveInput(
      'projectName',
      prompt: 'Enter Project Name:',
      defaultValue: 'my_dream_project',
      validators: [NonEmptyValidator(), ProjectNameValidator()],
    );
    final iosBundleId = resolveInput(
      'bundleId',
      prompt: 'Enter iOS Bundle Id:',
      defaultValue: 'sa.bond.com',
      validators: [IosBundleIdValidator()],
    );
    final androidApplicationId = resolveInput(
      'applicationId',
      prompt: 'Enter Android Application Id:',
      defaultValue: iosBundleId,
      validators: [AndroidAppIdValidator()],
    );
    final templateUrl = argResults!['template-url'] as String;
    final ref = argResults!['ref'] as String;

    final projectName = rawProjectName.toSnakeCase();
    final appName =
        (argResults!['appName'] as String?) ?? _displayName(rawProjectName);
    final projectDirectory = Directory(
      p.join(Directory.current.path, projectName),
    );
    logger.info('Creating "$appName" in ${projectDirectory.path}');

    await ProjectCloningTask(
      directory: projectDirectory,
      templateUrl: templateUrl,
      ref: ref,
    ).run();

    await SetupAndroidProjectTask(
      projectDirectory: projectDirectory,
      appName: appName,
      applicationId: androidApplicationId,
    ).run();

    await SetupIosProjectTask(
      projectDirectory: projectDirectory,
      appName: appName,
      bundleId: iosBundleId,
    ).run();

    await SetupFlutterProjectTask(
      projectDirectory: projectDirectory,
      projectName: projectName,
      pubGet: argResults!['pub-get'] as bool,
    ).run();

    await InitGitRepositoryTask(
      directory: projectDirectory,
      message: 'Initial commit from flutter-bond $ref',
    ).run();

    logger.success('Created $projectName in ${projectDirectory.path}');
  }

  /// `my_app` -> `My App`; names typed with spaces or capitals are kept.
  String _displayName(String projectName) {
    final trimmed = projectName.trim();
    return trimmed.contains(RegExp(r'[\sA-Z]'))
        ? trimmed
        : trimmed.toTitleCase();
  }
}
