import 'package:args/command_runner.dart';
import 'package:bond_cli/core/generators/generators.dart';
import 'package:bond_cli/core/upgrade/upgrade_project.dart';
import 'package:bond_cli/core/utils.dart';

/// `bond upgrade`: brings the template files of a project up to a newer
/// flutter-bond version.
class UpgradeCommand extends Command<void> with InputResolver {
  UpgradeCommand() {
    argParser
      ..addOption(
        'to',
        help: 'Template tag or branch to upgrade to (default: the newest tag).',
        valueHelp: 'v2.2.0',
      )
      ..addOption(
        'from',
        help:
            'Template version the project was created from. Only needed '
            'when the project has no bond.yaml.',
        valueHelp: 'v2.0.0',
      )
      ..addOption(
        'template-url',
        help:
            'Git URL or absolute local path of the flutter-bond template '
            '(default: bond.yaml, else $defaultTemplateUrl).',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Show what would change without touching any file.',
      )
      ..addFlag(
        'allow-dirty',
        negatable: false,
        help: 'Upgrade even with uncommitted changes in the git work tree.',
      );
  }

  @override
  String get name => 'upgrade';

  @override
  String get description =>
      'Upgrade the template files of this project (iOS, Android, config, '
      'scripts) to a newer flutter-bond version, on a new git branch.';

  @override
  Future<void> run() async {
    final report = await upgradeProject(
      project: requireFlutterProject(),
      to: argResults!['to'] as String?,
      from: argResults!['from'] as String?,
      templateUrl: argResults!['template-url'] as String?,
      dryRun: argResults!['dry-run'] as bool,
      allowDirty: argResults!['allow-dirty'] as bool,
    );
    logger.info(report.describe());
  }
}
