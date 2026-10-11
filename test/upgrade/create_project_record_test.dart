import 'dart:io';

import 'package:bond_cli/core/generators/generators.dart';
import 'package:bond_cli/core/upgrade/project_record.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fake_template.dart';

/// `bond create project` makes a commit, which needs a git identity.
final _noGitIdentity =
    Process.runSync('git', [
      'config',
      'user.email',
    ]).stdout.toString().trim().isEmpty
    ? 'git has no user.email on this machine'
    : null;

void main() {
  setUpAll(() => logger.level = Level.quiet);

  test(
    'create project records the template and drops template-only files',
    () async {
      final template = await FakeTemplate.create();
      await template.release('v1', files: FakeTemplate.baseFiles());
      final parent = Directory.systemTemp.createTempSync('bond_create_');
      addTearDown(() {
        template.dispose();
        parent.deleteSync(recursive: true);
      });

      final result = await generateProject(
        parent: parent,
        projectName: 'my_app',
        bundleId: 'com.acme.app',
        appName: 'My App',
        templateUrl: template.url,
        ref: 'v1',
        pubGet: false,
      );

      final dir = Directory(result.files.single);
      expect(File(p.join(dir.path, 'context7.json')).existsSync(), isFalse);
      final record = ProjectRecord.read(dir)!;
      expect(record.ref, 'v1');
      expect(record.templateUrl, template.url);
      expect(record.identity.name, 'my_app');
      expect(record.identity.appName, 'My App');
      expect(record.identity.applicationId, 'com.acme.app');
      // bond.yaml is part of the first commit.
      expect(await git(dir, ['status', '--porcelain']), isEmpty);
      expect(await git(dir, ['ls-files', 'bond.yaml']), contains('bond.yaml'));
    },
    skip: _noGitIdentity,
  );
}
