import 'dart:io';
import 'dart:typed_data';

import 'package:bond_cli/core/utils/process.dart';
import 'package:path/path.dart' as p;

import 'template_files.dart';
import 'upgrade_report.dart';

/// Merges the changes between two template versions into [project].
///
/// [base] is the old version and [theirs] the new one, both rendered with the
/// project's names (see `TemplateSnapshot`); the project's own files are
/// "yours". Text files are merged with `git merge-file`; see
/// [isOwnedFile] for the files that are never merged line by line. With
/// [dryRun] nothing is written.
Future<void> mergeTemplates({
  required Directory project,
  required Map<String, File> base,
  required Map<String, File> theirs,
  required UpgradeReport report,
  bool dryRun = false,
}) async {
  final temp = Directory.systemTemp.createTempSync('bond_merge_');
  try {
    final paths = {...base.keys, ...theirs.keys}.toList()..sort();
    for (final path in paths) {
      await _mergeFile(
        project: project,
        path: path,
        base: base[path],
        theirs: theirs[path],
        report: report,
        dryRun: dryRun,
        temp: temp,
      );
    }
  } finally {
    temp.deleteSync(recursive: true);
  }
}

Future<void> _mergeFile({
  required Directory project,
  required String path,
  required File? base,
  required File? theirs,
  required UpgradeReport report,
  required bool dryRun,
  required Directory temp,
}) async {
  final oursFile = File(p.join(project.path, p.joinAll(path.split('/'))));
  final oursExists = oursFile.existsSync();
  if (!oursExists && Directory(oursFile.path).existsSync()) {
    report.kept.add((path: path, reason: 'a folder with this name exists'));
    return;
  }
  final ours = oursExists ? oursFile.readAsBytesSync() : null;

  // The app's own version number is not the template's.
  Uint8List? read(File? file) {
    if (file == null) return null;
    final bytes = file.readAsBytesSync();
    return path == 'pubspec.yaml' && ours != null
        ? _withVersionOf(bytes, ours)
        : bytes;
  }

  final baseBytes = read(base);
  final theirsBytes = read(theirs);

  if (theirsBytes == null) {
    // The template removed the file.
    if (ours == null) return;
    if (_same(ours, baseBytes!)) {
      report.removed.add(path);
      if (!dryRun) _delete(oursFile, project);
    } else {
      report.kept.add((path: path, reason: 'removed by the template, edited'));
    }
    return;
  }

  if (baseBytes != null && _same(baseBytes, theirsBytes)) return;
  if (ours != null && _same(ours, theirsBytes)) return;

  final owned = isOwnedFile(
    path,
    binary: looksBinary(theirsBytes) || (ours != null && looksBinary(ours)),
  );

  if (baseBytes == null) {
    // New in the template.
    if (ours == null) {
      report.added.add(path);
      if (!dryRun) _write(oursFile, theirsBytes, mode: theirs);
    } else if (owned) {
      report.kept.add((path: path, reason: 'new in the template, you have it'));
    } else {
      report.sidecars.add(path);
      if (!dryRun) _write(File('${oursFile.path}.template'), theirsBytes);
    }
    return;
  }

  // Changed in the template.
  if (ours == null) {
    report.skipped.add(path);
    return;
  }
  if (_same(ours, baseBytes)) {
    report.applied.add(path);
    if (!dryRun) _write(oursFile, theirsBytes);
    return;
  }
  if (owned) {
    report.kept.add((
      path: path,
      reason: 'generated, binary or Firebase file; you changed it',
    ));
    return;
  }

  final baseCopy = File(p.join(temp.path, 'base'))..writeAsBytesSync(baseBytes);
  final theirsCopy = File(p.join(temp.path, 'theirs'))
    ..writeAsBytesSync(theirsBytes);
  final result = await Process.run(
    'git',
    [
      'merge-file',
      '-p',
      '-L',
      'yours',
      '-L',
      'template ${report.fromRef}',
      '-L',
      'template ${report.toRef}',
      oursFile.path,
      baseCopy.path,
      theirsCopy.path,
    ],
    stdoutEncoding: null,
    stderrEncoding: null,
    runInShell: Platform.isWindows,
  );
  final conflicts = result.exitCode;
  if (conflicts < 0 || conflicts > 127) {
    throw ProcessFailure(
      '`git merge-file` failed for $path: '
      '${String.fromCharCodes(result.stderr as List<int>).trim()}',
    );
  }
  if (!dryRun) _write(oursFile, Uint8List.fromList(result.stdout as List<int>));
  if (conflicts == 0) {
    report.applied.add(path);
  } else {
    report.conflicts.add((path: path, hunks: conflicts));
  }
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

final _versionLine = RegExp(r'^version:.*$', multiLine: true);

/// [pubspec] with its `version:` line replaced by the one of [ours].
Uint8List _withVersionOf(List<int> pubspec, List<int> ours) {
  final mine = _versionLine.firstMatch(String.fromCharCodes(ours))?.group(0);
  if (mine == null) return Uint8List.fromList(pubspec);
  return Uint8List.fromList(
    String.fromCharCodes(pubspec).replaceFirst(_versionLine, mine).codeUnits,
  );
}

/// Writes [bytes] to [file]; a new file gets the mode of [mode], so
/// scripts stay executable.
void _write(File file, List<int> bytes, {File? mode}) {
  final isNew = !file.existsSync();
  file.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  if (isNew && mode != null && !Platform.isWindows) {
    final bits = mode.statSync().mode & 0x1ff;
    Process.runSync('chmod', [bits.toRadixString(8), file.path]);
  }
}

/// Deletes [file] and the folders it leaves empty, up to [root].
void _delete(File file, Directory root) {
  file.deleteSync();
  var dir = file.parent;
  while (p.isWithin(root.path, dir.path) &&
      dir.existsSync() &&
      dir.listSync().isEmpty) {
    dir.deleteSync();
    dir = dir.parent;
  }
}
