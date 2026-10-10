import 'dart:io';

import 'package:path/path.dart' as p;

/// Thrown when an external command is missing or exits with a non-zero code.
class ProcessFailure implements Exception {
  final String message;

  ProcessFailure(this.message);

  @override
  String toString() => message;
}

/// Runs [executable] and throws a [ProcessFailure] with its output when it
/// cannot be started or exits with a non-zero code.
Future<ProcessResult> runProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final command = [executable, ...arguments].join(' ');
  final ProcessResult result;
  try {
    result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
    );
  } on ProcessException catch (error) {
    throw ProcessFailure('Could not run `$command`: ${error.message}');
  }
  if (result.exitCode != 0) {
    throw ProcessFailure(
      '`$command` failed with exit code ${result.exitCode}.\n'
              '${result.stderr}${result.stdout}'
          .trim(),
    );
  }
  return result;
}

bool? _fvmInstalled;

/// Runs a `flutter` or `dart` [tool] command in [project], through FVM when
/// the project pins its Flutter version in `.fvmrc` and FVM is installed.
Future<ProcessResult> runFlutterTool(
  Directory project,
  String tool,
  List<String> arguments,
) async {
  final usesFvm =
      File(p.join(project.path, '.fvmrc')).existsSync() &&
      (_fvmInstalled ??= await _canRun('fvm', ['--version']));
  return usesFvm
      ? runProcess('fvm', [tool, ...arguments], workingDirectory: project.path)
      : runProcess(tool, arguments, workingDirectory: project.path);
}

Future<bool> _canRun(String executable, List<String> arguments) async {
  try {
    final result = await Process.run(
      executable,
      arguments,
      runInShell: Platform.isWindows,
    );
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
