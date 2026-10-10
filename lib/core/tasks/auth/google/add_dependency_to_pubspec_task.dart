import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';

class AddDependencyToPubspecTask extends Task {
  static const dependency = 'google_sign_in: ^7.2.0';

  @override
  String get actionDescription =>
      'Add google_sign_in dependency to pubspec.yaml.';

  @override
  Future<void> execute() async {
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw Exception('pubspec.yaml not found.');
    }

    final content = pubspecFile.readAsStringSync();
    if (RegExp(r'^\s+google_sign_in:', multiLine: true).hasMatch(content)) {
      warn('google_sign_in is already a dependency in pubspec.yaml.');
      return;
    }
    final dependencies = RegExp(r'^dependencies:[ \t]*$', multiLine: true);
    if (!dependencies.hasMatch(content)) {
      throw Exception('No dependencies section in pubspec.yaml.');
    }
    pubspecFile.writeAsStringSync(
      content.replaceFirstMapped(dependencies, (m) => '${m[0]}\n  $dependency'),
    );
  }
}
