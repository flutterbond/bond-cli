import 'dart:io';

import 'package:bond_cli/core/generators/generators.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/utils/process.dart';

import 'project_record.dart';
import 'template_snapshot.dart';
import 'three_way_merge.dart';
import 'upgrade_report.dart';

/// `bond upgrade` cannot continue; the message says what to do.
class UpgradeError implements Exception {
  UpgradeError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Upgrades the template files of [project] from the template version it was
/// created from (`bond.yaml`, or [from]) to [to] (default: the newest tag).
///
/// Renders both versions with the project's names, merges what changed into
/// the project on a new branch and leaves everything uncommitted. With
/// [dryRun] it only reports. Never touches the working directory.
Future<UpgradeReport> upgradeProject({
  required Directory project,
  String? to,
  String? from,
  String? templateUrl,
  bool dryRun = false,
  bool allowDirty = false,
}) async {
  final warnings = <String>[];
  var record = ProjectRecord.read(project);
  final url = templateUrl ?? record?.templateUrl ?? defaultTemplateUrl;

  // The project's files are the truth; the record may predate `bond update`.
  ProjectIdentity? identity;
  try {
    final detected = ProjectIdentity.detect(project);
    identity = detected.identity;
    warnings.addAll(detected.warnings);
  } on FormatException catch (error) {
    if (record == null) throw UpgradeError(error.message);
  }
  identity ??= record!.identity;

  final fromRef = from ?? record?.ref;
  if (fromRef == null) {
    throw UpgradeError(
      'This project has no ${ProjectRecord.fileName}, so the template '
      'version it was created from is unknown. Pass it with --from <ref>, '
      'for example --from v2.0.0 (see "Initial commit from flutter-bond '
      '<ref>" in `git log`).',
    );
  }
  final toRef = to ?? await latestTemplateRef(url);
  final report = UpgradeReport(fromRef: fromRef, toRef: toRef, dryRun: dryRun)
    ..warnings.addAll(warnings);
  if (report.upToDate) return report;

  await _requireCleanGitProject(project, allowDirty: allowDirty);

  logger.info('Rendering template $fromRef and $toRef with your names...');
  final base = await TemplateSnapshot.render(
    templateUrl: url,
    ref: fromRef,
    identity: identity,
  );
  try {
    final target = await TemplateSnapshot.render(
      templateUrl: url,
      ref: toRef,
      identity: identity,
    );
    try {
      final branch = 'bond/upgrade-$toRef';
      if (!dryRun) {
        await _createBranch(project, branch);
        report.branch = branch;
      }
      await mergeTemplates(
        project: project,
        base: base.files,
        theirs: target.files,
        report: report,
        dryRun: dryRun,
      );
    } finally {
      target.dispose();
    }
  } finally {
    base.dispose();
  }

  record = ProjectRecord(templateUrl: url, ref: toRef, identity: identity);
  if (!dryRun) record.write(project);
  _addFollowUp(report);
  return report;
}

Future<void> _requireCleanGitProject(
  Directory project, {
  required bool allowDirty,
}) async {
  try {
    await runProcess('git', [
      'rev-parse',
      '--is-inside-work-tree',
    ], workingDirectory: project.path);
  } on ProcessFailure {
    throw UpgradeError(
      '${project.path} is not a git repository. Run `git init` and commit '
      'your work first, so the upgrade can be reviewed and undone.',
    );
  }
  final status = await runProcess('git', [
    'status',
    '--porcelain',
  ], workingDirectory: project.path);
  if ('${status.stdout}'.trim().isNotEmpty && !allowDirty) {
    throw UpgradeError(
      'The git working tree has uncommitted changes. Commit or stash them '
      'first, or pass --allow-dirty.',
    );
  }
}

Future<void> _createBranch(Directory project, String branch) async {
  try {
    await runProcess('git', [
      'switch',
      '--create',
      branch,
    ], workingDirectory: project.path);
  } on ProcessFailure catch (error) {
    throw UpgradeError(
      'Could not create the branch $branch (does it exist already?): '
      '${error.message}',
    );
  }
}

void _addFollowUp(UpgradeReport report) {
  final steps = report.followUp;
  if (report.dryRun) {
    steps.add('Run it without --dry-run to apply these changes on a branch.');
    return;
  }
  steps.add('Review the changes with `git status` and `git diff`.');
  if (report.conflicts.isNotEmpty) {
    steps.add(
      'Resolve the conflict markers in: '
      '${report.conflicts.map((c) => c.path).join(', ')}.',
    );
  }
  if (report.sidecars.isNotEmpty) {
    steps.add(
      'Merge the settings you want from each <file>.template, then delete it.',
    );
  }
  steps
    ..add(
      'Run `flutter pub upgrade` for the bond_* packages, then `flutter pub '
      'get`.',
    )
    ..add(
      'Run `dart fix --dry-run`, then `dart fix --apply`, to migrate renamed '
      'APIs.',
    )
    ..add('Read MIGRATION.md of the template for ${report.toRef}.');
}
