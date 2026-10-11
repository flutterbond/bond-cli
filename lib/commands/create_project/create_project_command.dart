import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:bond_cli/core/generators/generators.dart';
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
    final appName =
        (argResults!['appName'] as String?) ??
        projectDisplayName(rawProjectName);
    logger.info(
      'Creating "$appName" in '
      '${p.join(Directory.current.path, rawProjectName.toSnakeCase())}',
    );

    final result = await generateProject(
      parent: Directory.current,
      projectName: rawProjectName,
      bundleId: iosBundleId,
      applicationId: androidApplicationId,
      appName: appName,
      templateUrl: templateUrl,
      ref: ref,
      pubGet: argResults!['pub-get'] as bool,
    );

    logger.success('Created ${result.files.single}');
    for (final line in result.followUp) {
      logger.info(line);
    }
  }
}
