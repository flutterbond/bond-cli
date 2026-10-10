import 'dart:convert';
import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';

class UpdateEnvironmentFilesTask extends Task {
  static const envFiles = ['env.json', 'env.staging.json', 'env.example.json'];

  @override
  String get actionDescription =>
      'Add Google Sign-In variables to the env*.json files.';

  @override
  Future<void> execute() async {
    const variables = {
      'GOOGLE_CLIENT_ID': 'Your-Google-Client-ID',
      'GOOGLE_SCOPES': 'email,profile',
      'GOOGLE_SERVER_CLIENT_ID': 'Your-Google-Server-Client-ID',
      'GOOGLE_REVERSED_CLIENT_ID':
          'com.googleusercontent.apps.your-reversed-client-id',
    };

    final files = envFiles.map(File.new).where((file) => file.existsSync());
    if (files.isEmpty) {
      throw Exception('None of ${envFiles.join(', ')} found.');
    }
    for (final file in files) {
      final content =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      // Placeholders only fill gaps; values already set are kept.
      for (final MapEntry(:key, :value) in variables.entries) {
        content.putIfAbsent(key, () => value);
      }
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(content)}\n',
      );
    }
  }
}
