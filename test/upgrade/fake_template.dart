import 'dart:io';

import 'package:bond_cli/core/upgrade/project_record.dart';
import 'package:bond_cli/core/upgrade/template_snapshot.dart';
import 'package:path/path.dart' as p;

/// Runs git with a fixed identity, so tests do not depend on the machine's
/// git configuration.
Future<String> git(Directory dir, List<String> args) async {
  final result = await Process.run('git', [
    '-c',
    'user.name=Test',
    '-c',
    'user.email=test@example.com',
    '-c',
    'commit.gpgsign=false',
    '-c',
    'tag.gpgsign=false',
    ...args,
  ], workingDirectory: dir.path);
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
  return '${result.stdout}';
}

/// The identity used for the projects of these tests.
const testIdentity = ProjectIdentity(
  name: 'my_app',
  appName: 'My App',
  bundleId: 'com.acme.app',
  applicationId: 'com.acme.app',
);

/// A flutter-bond-like template in a git repository, with the few Android and
/// iOS files the rename tasks need. Files are `String` or `List<int>`.
class FakeTemplate {
  FakeTemplate._(this.directory);

  final Directory directory;

  String get url => directory.path;

  static Future<FakeTemplate> create() async {
    final directory = Directory.systemTemp.createTempSync('bond_template_');
    await git(directory, ['init', '--quiet']);
    return FakeTemplate._(directory);
  }

  /// Commits [files] (and the removal of [remove]) and tags the commit [tag].
  Future<void> release(
    String tag, {
    Map<String, Object> files = const {},
    List<String> remove = const [],
    Set<String> executable = const {},
  }) async {
    for (final entry in files.entries) {
      final file = File(p.join(directory.path, entry.key))
        ..createSync(recursive: true);
      final value = entry.value;
      value is String
          ? file.writeAsStringSync(value)
          : file.writeAsBytesSync(value as List<int>);
    }
    for (final path in remove) {
      File(p.join(directory.path, path)).deleteSync();
    }
    for (final path in executable) {
      await Process.run('chmod', ['755', p.join(directory.path, path)]);
    }
    await git(directory, ['add', '--all']);
    await git(directory, ['commit', '--quiet', '--message', tag]);
    await git(directory, ['tag', '--annotate', '--message', tag, tag]);
  }

  void dispose() => directory.deleteSync(recursive: true);

  /// The files every version of the template has: package `bond`, Android
  /// `ps.app.bond` and iOS `ps.app.bond`, named "Bond".
  static Map<String, Object> baseFiles() => {
    'pubspec.yaml':
        'name: bond\nversion: 1.0.0+1\n\ndependencies:\n  dio: ^5.0.0\n',
    'context7.json': '{"projectTitle": "template only"}\n',
    'lib/main.dart':
        "import 'package:bond/home.dart';\n\nvoid main() => home();\n",
    'lib/home.dart':
        'void home() {\n'
        "  print('one');\n"
        "  print('two');\n"
        "  print('three');\n"
        "  print('four');\n"
        "  print('five');\n"
        "  print('six');\n"
        "  print('seven');\n"
        '}\n',
    'lib/legacy.dart': '// removed in v2\n',
    'lib/helper.dart': '// helper v1\n',
    'lib/app.g.dart': '// generated v1\n',
    'assets/icon.png': [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 1],
    'android/app/build.gradle.kts':
        'android {\n'
        '    namespace = "ps.app.bond"\n'
        '    defaultConfig {\n'
        '        applicationId = "ps.app.bond"\n'
        '    }\n'
        '}\n',
    'android/app/src/main/AndroidManifest.xml':
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '</manifest>\n',
    'android/app/src/main/kotlin/ps/app/bond/MainActivity.kt':
        'package ps.app.bond\n\nclass MainActivity\n',
    'android/app/src/main/res/values/strings.xml':
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <string name="app_name">Bond</string>\n'
        '</resources>\n',
    'ios/Runner.xcodeproj/project.pbxproj':
        '// !\$*UTF8*\$!\n{\n\tobjects = {\n'
        '/* Begin XCBuildConfiguration section */\n'
        '\t\tA0 /* Debug */ = {\n'
        '\t\t\tisa = XCBuildConfiguration;\n'
        '\t\t\tbuildSettings = {\n'
        '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = ps.app.bond;\n'
        '\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";\n'
        '\t\t\t};\n'
        '\t\t\tname = "Debug";\n'
        '\t\t};\n'
        '/* End XCBuildConfiguration section */\n'
        '\t};\n}\n',
    'ios/Runner/Info.plist':
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<plist version="1.0">\n'
        '<dict>\n'
        '\t<key>CFBundleDisplayName</key>\n'
        '\t<string>Bond</string>\n'
        '\t<key>CFBundleName</key>\n'
        '\t<string>bond</string>\n'
        '</dict>\n'
        '</plist>\n',
  };
}

/// Creates a project from [ref] of [template] the way `bond create project`
/// does (renamed, with a `bond.yaml` and one commit), without needing a git
/// identity on the machine.
Future<Directory> createProject(
  FakeTemplate template,
  Directory parent, {
  String ref = 'v1',
  bool record = true,
}) async {
  final directory = Directory(p.join(parent.path, testIdentity.name));
  await renderTemplate(
    directory: directory,
    templateUrl: template.url,
    ref: ref,
    identity: testIdentity,
  );
  if (record) {
    ProjectRecord(
      templateUrl: template.url,
      ref: ref,
      identity: testIdentity,
    ).write(directory);
  }
  await git(directory, ['init', '--quiet']);
  await git(directory, ['add', '--all']);
  await git(directory, ['commit', '--quiet', '--message', 'Initial commit']);
  return directory;
}
