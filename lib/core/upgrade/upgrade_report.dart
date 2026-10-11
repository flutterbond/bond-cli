/// What `bond upgrade` did (or, with a dry run, would do) to a project.
class UpgradeReport {
  UpgradeReport({
    required this.fromRef,
    required this.toRef,
    required this.dryRun,
  });

  final String fromRef;
  final String toRef;
  final bool dryRun;

  /// The branch the changes were made on (null for a dry run or "up to date").
  String? branch;

  /// Files updated from the new template version without conflicts.
  final applied = <String>[];

  /// Files the new template version added.
  final added = <String>[];

  /// Files the template removed and the project had not changed.
  final removed = <String>[];

  /// Files merged with conflict markers, with the number of conflicts.
  final conflicts = <({String path, int hunks})>[];

  /// Files that exist in the project and in the template but are new there:
  /// the template's version is written next to them as `<path>.template`.
  final sidecars = <String>[];

  /// Files left as they are, with the reason.
  final kept = <({String path, String reason})>[];

  /// Files the project deleted, so they are not brought back.
  final skipped = <String>[];

  final warnings = <String>[];
  final followUp = <String>[];

  bool get upToDate => fromRef == toRef;

  bool get changedAnything =>
      applied.isNotEmpty ||
      added.isNotEmpty ||
      removed.isNotEmpty ||
      conflicts.isNotEmpty ||
      sidecars.isNotEmpty;

  Map<String, Object?> toJson() => {
    'from': fromRef,
    'to': toRef,
    'dryRun': dryRun,
    'branch': branch,
    'applied': applied,
    'added': added,
    'removed': removed,
    'conflicts': [
      for (final c in conflicts) {'path': c.path, 'conflicts': c.hunks},
    ],
    'sidecars': sidecars,
    'kept': [
      for (final k in kept) {'path': k.path, 'reason': k.reason},
    ],
    'skipped': skipped,
    'warnings': warnings,
    'followUp': followUp,
  };

  /// A readable summary, for the terminal and for MCP clients.
  String describe() {
    final out = StringBuffer();
    if (upToDate) {
      out.writeln('Already at template $toRef; nothing to upgrade.');
      return out.toString();
    }
    out.writeln(
      '${dryRun ? 'Would upgrade' : 'Upgraded'} the template files '
      '$fromRef -> $toRef'
      '${branch == null ? '' : ' on branch $branch'}:',
    );
    void section(String title, Iterable<String> lines) {
      if (lines.isEmpty) return;
      out.writeln('\n$title (${lines.length}):');
      for (final line in lines) {
        out.writeln('- $line');
      }
    }

    section('Updated', applied);
    section('Added', added);
    section('Removed', removed);
    section('Conflicts, resolve the <<<<<<< markers', [
      for (final c in conflicts)
        '${c.path} (${c.hunks} conflict${c.hunks == 1 ? '' : 's'})',
    ]);
    section('Already in your project, compare with <file>.template', sidecars);
    section('Kept yours', [for (final k in kept) '${k.path}: ${k.reason}']);
    section('Not restored (you deleted them)', skipped);
    if (!changedAnything && kept.isEmpty && skipped.isEmpty) {
      out.writeln('\nThe template has nothing new for this project.');
    }
    if (warnings.isNotEmpty) {
      out.writeln('\nWarnings:');
      for (final warning in warnings) {
        out.writeln('- $warning');
      }
    }
    if (followUp.isNotEmpty) {
      out.writeln('\nNext:');
      for (final step in followUp) {
        out.writeln('- $step');
      }
    }
    return out.toString();
  }
}
