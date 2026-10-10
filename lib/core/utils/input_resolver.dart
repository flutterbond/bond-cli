import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:bond_cli/core/validators.dart';
import 'package:path/path.dart' as p;

import 'logger.dart';

/// Reads command inputs from options first and prompts only for missing ones.
mixin InputResolver<T> on Command<T> {
  /// Returns the validated value of [option], prompting for it when missing.
  ///
  /// Without a terminal nothing can be prompted: [fallback] is used when
  /// given, otherwise the command fails with a usage error naming [option].
  String resolveInput(
    String option, {
    required String prompt,
    String? defaultValue,
    String? fallback,
    List<Validator<String>> validators = const [],
  }) {
    final validator = CompositeValidator(validators);
    final value = argResults?[option] as String?;
    if (value != null) {
      final error = validator.validate(value);
      if (error != null) usageException('--$option: $error');
      return value;
    }

    if (!stdin.hasTerminal || !stdout.hasTerminal) {
      if (fallback != null) return fallback;
      usageException('Missing --$option (no terminal to prompt for it).');
    }

    while (true) {
      final input = logger.prompt(prompt, defaultValue: defaultValue).trim();
      final error = validator.validate(input);
      if (error == null) return input;
      logger.err(error);
    }
  }

  /// The current directory, which must be the root of a Flutter project.
  Directory requireFlutterProject() {
    final directory = Directory.current;
    if (!File(p.join(directory.path, 'pubspec.yaml')).existsSync()) {
      usageException(
        'Run this command from the root of a Flutter project '
        '(no pubspec.yaml in ${directory.path}).',
      );
    }
    return directory;
  }
}
