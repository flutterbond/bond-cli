import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// A temporary project whose `.dart_tool/package_config.json` resolves:
/// - `bond_core` 0.1.0 as a hosted package in a fake pub cache (absolute URI),
/// - `bond_form` 0.1.0 as a path package (relative URI, like a pub workspace),
/// - `bond_cli` and `http` (both must be ignored).
class FakeProject {
  FakeProject._(this.tempDir);

  final Directory tempDir;

  String get root => p.join(tempDir.path, 'app');
  String get pubCache => p.join(tempDir.path, 'pub-cache');
  String get bondCoreRoot =>
      p.join(pubCache, 'hosted', 'pub.dev', 'bond_core-0.1.0');
  String get bondFormRoot => p.join(tempDir.path, 'packages', 'form');

  static FakeProject create() {
    final project = FakeProject._(
      Directory.systemTemp.createTempSync('bond_mcp_'),
    );
    project._writePackage(
      project.bondCoreRoot,
      name: 'bond_core',
      version: '0.1.0',
      description: 'Core of Bond.',
      readme: '# bond_core\n\nService providers and `sl`.',
      changelog: '# Changelog\n\n## 0.1.0\n\n- material_ui types.\n\n## 0.0.3\n\n- Old.\n',
      libFiles: {
        'bond_core.dart': "library;\n\nexport 'src/service_provider.dart';\n",
        'src/service_provider.dart':
            '/// Registers services.\nabstract class ServiceProvider {\n'
            '  /// Registers into [it].\n  Future<void> register(Object it);\n}\n',
      },
      example: '```dart\nvoid main() {}\n```',
    );
    project._writePackage(
      project.bondFormRoot,
      name: 'bond_form',
      version: '0.1.0',
      description: 'Forms of Bond.',
      readme: '# bond_form',
      changelog: '## 0.1.0\n\n- dateAfter fix.\n\n## 0.0.22+19\n\n- Older.\n',
      libFiles: {
        'bond_form.dart': "library;\n\nexport 'src/rules.dart';\n",
        'validator_localizations.dart': 'class ValidatorLocalizations {}\n',
        'src/rules.dart': 'class Rules {}\n',
        'src/rules.g.dart': '// generated\n',
      },
    );
    final config = {
      'configVersion': 2,
      'packages': [
        {
          'name': 'bond_core',
          'rootUri': Uri.directory(project.bondCoreRoot).toString(),
          'packageUri': 'lib/',
        },
        {
          'name': 'bond_form',
          'rootUri': '../../packages/form',
          'packageUri': 'lib/',
        },
        {'name': 'bond_cli', 'rootUri': '../../bond_cli', 'packageUri': 'lib/'},
        {'name': 'http', 'rootUri': '../../http', 'packageUri': 'lib/'},
        {'name': 'app', 'rootUri': '../', 'packageUri': 'lib/'},
      ],
    };
    File(p.join(project.root, '.dart_tool', 'package_config.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(config));
    File(p.join(project.root, 'pubspec.yaml')).writeAsStringSync('name: app\n');
    return project;
  }

  void delete() => tempDir.deleteSync(recursive: true);

  void _writePackage(
    String root, {
    required String name,
    required String version,
    required String description,
    required String readme,
    required String changelog,
    required Map<String, String> libFiles,
    String? example,
  }) {
    File(p.join(root, 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'name: $name\nversion: $version\ndescription: $description\n',
      );
    File(p.join(root, 'README.md')).writeAsStringSync(readme);
    File(p.join(root, 'CHANGELOG.md')).writeAsStringSync(changelog);
    if (example != null) {
      File(p.join(root, 'example', 'example.md'))
        ..createSync(recursive: true)
        ..writeAsStringSync(example);
    }
    for (final MapEntry(key: path, value: content) in libFiles.entries) {
      File(p.join(root, 'lib', path))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }
  }
}
