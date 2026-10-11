import 'dart:io';

import 'package:bond_cli/core/upgrade/project_record.dart';
import 'package:bond_cli/core/upgrade/template_snapshot.dart';
import 'package:bond_cli/core/upgrade/upgrade_project.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fake_template.dart';

void main() {
  late FakeTemplate template;
  late Directory workspace;
  late Directory project;

  setUpAll(() => logger.level = Level.quiet);

  File file(String path) =>
      File(p.join(project.path, p.joinAll(path.split('/'))));
  String read(String path) => file(path).readAsStringSync();

  /// v2 changes: edits, an addition, a removal, a script, a binary, a
  /// generated file, a new dependency and a version bump.
  Future<void> releaseV2() => template.release(
    'v2',
    files: {
      'pubspec.yaml': 'name: bond\nversion: 2.0.0+1\n\ndependencies:\n  dio: ^5.0.0\n  collection: ^1.0.0\n',
      'lib/home.dart': FakeTemplate.baseFiles()['lib/home.dart']
          .toString()
          .replaceFirst("'seven'", "'SEVEN from v2'"),
      'lib/new_screen.dart':
          "import 'package:bond/home.dart';\n\nvoid screen() => home();\n",
      'lib/helper.dart': '// helper v2\n',
      'lib/app.g.dart': '// generated v2\n',
      'assets/icon.png': [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 2],
      'tool/run.sh': '#!/bin/sh\necho run\n',
      'config.json': '{"template": true}\n',
    },
    remove: ['lib/legacy.dart'],
    executable: {'tool/run.sh'},
  );

  setUp(() async {
    template = await FakeTemplate.create();
    await template.release('v1', files: FakeTemplate.baseFiles());
    workspace = Directory.systemTemp.createTempSync('bond_workspace_');
    project = await createProject(template, workspace);
  });

  tearDown(() {
    template.dispose();
    workspace.deleteSync(recursive: true);
  });

  test('renders the template with the project names', () async {
    final snapshot = await TemplateSnapshot.render(
      templateUrl: template.url,
      ref: 'v1',
      identity: testIdentity,
    );
    addTearDown(snapshot.dispose);

    expect(snapshot.files.containsKey('context7.json'), isFalse);
    expect(
      snapshot.files['lib/main.dart']!.readAsStringSync(),
      contains('package:my_app/home.dart'),
    );
    expect(
      snapshot.files['pubspec.yaml']!.readAsStringSync(),
      startsWith('name: my_app'),
    );
    expect(snapshot.files.containsKey('.git/HEAD'), isFalse);
  });

  test('the newest release tag is the default target', () async {
    expect(await latestTemplateRef(template.url), 'v1');
    await releaseV2();
    await template.release('v3-beta', files: {'beta.txt': 'x'});
    await template.release('experimental', files: {'x.txt': 'x'});

    expect(await latestTemplateRef(template.url), 'v2');
  });

  group('upgrading', () {
    test('applies the template changes on a new branch, uncommitted', () async {
      await releaseV2();

      final report = await upgradeProject(project: project);

      expect(report.fromRef, 'v1');
      expect(report.toRef, 'v2');
      expect(report.branch, 'bond/upgrade-v2');
      expect(
        (await git(project, ['branch', '--show-current'])).trim(),
        'bond/upgrade-v2',
      );
      expect(
        report.applied,
        containsAll([
          'lib/home.dart',
          'lib/helper.dart',
          'lib/app.g.dart',
          'assets/icon.png',
          'pubspec.yaml',
        ]),
      );
      expect(report.added, containsAll(['lib/new_screen.dart', 'tool/run.sh']));
      expect(report.removed, ['lib/legacy.dart']);
      expect(report.conflicts, isEmpty);

      expect(read('lib/home.dart'), contains('SEVEN from v2'));
      expect(read('lib/new_screen.dart'), contains('package:my_app/home.dart'));
      expect(file('lib/legacy.dart').existsSync(), isFalse);
      expect(file('context7.json').existsSync(), isFalse);
      expect(file('assets/icon.png').readAsBytesSync().last, 2);
      // The app's version stays; the template's new dependency arrives.
      expect(
        read('pubspec.yaml'),
        allOf(
          contains('name: my_app'),
          contains('version: 1.0.0+1'),
          contains('collection: ^1.0.0'),
        ),
      );
      expect(ProjectRecord.read(project)!.ref, 'v2');
      expect(
        (await git(project, ['log', '--oneline'])).trim().split('\n'),
        hasLength(1),
        reason: 'nothing is committed',
      );
      if (!Platform.isWindows) {
        expect(file('tool/run.sh').statSync().mode & 0x40, isNonZero);
      }
    });

    test('merges edits of the project and marks real conflicts', () async {
      // Far from the template's change: merges cleanly.
      file('lib/home.dart').writeAsStringSync(
        read('lib/home.dart').replaceFirst("'one'", "'ONE mine'"),
      );
      file('lib/helper.dart').writeAsStringSync('// helper mine\n');
      await git(project, ['commit', '--all', '--quiet', '--message', 'edits']);
      await releaseV2();

      final report = await upgradeProject(project: project);

      expect(
        read('lib/home.dart'),
        allOf(contains('ONE mine'), contains('SEVEN from v2')),
      );
      expect(report.conflicts, [(path: 'lib/helper.dart', hunks: 1)]);
      expect(
        read('lib/helper.dart'),
        allOf(
          contains('<<<<<<< yours'),
          contains('// helper mine'),
          contains('======='),
          contains('// helper v2'),
          contains('>>>>>>> template v2'),
        ),
      );
      expect(report.followUp.join('\n'), contains('lib/helper.dart'));
    });

    test('keeps what the project changed or deleted', () async {
      file('lib/legacy.dart').writeAsStringSync('// still needed\n');
      file('lib/app.g.dart').writeAsStringSync('// regenerated mine\n');
      file('lib/helper.dart').deleteSync();
      file('assets/icon.png').writeAsBytesSync([137, 80, 78, 71, 0, 9, 9]);
      await git(project, ['add', '--all']);
      await git(project, ['commit', '--quiet', '--message', 'edits']);
      await releaseV2();

      final report = await upgradeProject(project: project);

      expect(report.skipped, ['lib/helper.dart']);
      expect(file('lib/helper.dart').existsSync(), isFalse);
      expect(read('lib/legacy.dart'), '// still needed\n');
      expect(read('lib/app.g.dart'), '// regenerated mine\n');
      expect(file('assets/icon.png').readAsBytesSync(), [
        137,
        80,
        78,
        71,
        0,
        9,
        9,
      ]);
      expect(
        report.kept.map((k) => k.path),
        containsAll(['lib/legacy.dart', 'lib/app.g.dart', 'assets/icon.png']),
      );
    });

    test(
      'a file added by the template that the project has is not merged',
      () async {
        file('config.json').writeAsStringSync('{"mine": true}\n');
        await git(project, ['add', '--all']);
        await git(project, ['commit', '--quiet', '--message', 'config']);
        await releaseV2();

        final report = await upgradeProject(project: project);

        expect(report.sidecars, ['config.json']);
        expect(read('config.json'), '{"mine": true}\n');
        expect(read('config.json.template'), '{"template": true}\n');
      },
    );

    test('a dry run reports the same without writing anything', () async {
      await releaseV2();
      final before = await git(project, ['status', '--porcelain']);

      final report = await upgradeProject(project: project, dryRun: true);

      expect(report.dryRun, isTrue);
      expect(report.branch, isNull);
      expect(report.added, contains('lib/new_screen.dart'));
      expect(await git(project, ['status', '--porcelain']), before);
      expect(
        (await git(project, ['branch', '--show-current'])).trim(),
        isNot('bond/upgrade-v2'),
      );
      expect(ProjectRecord.read(project)!.ref, 'v1');
      expect(report.describe(), contains('Would upgrade'));
    });

    test('refuses uncommitted changes unless allowed', () async {
      await releaseV2();
      file('lib/home.dart').writeAsStringSync('// dirty\n');

      await expectLater(
        upgradeProject(project: project),
        throwsA(
          isA<UpgradeError>().having(
            (e) => e.message,
            'message',
            contains('uncommitted'),
          ),
        ),
      );
      expect(ProjectRecord.read(project)!.ref, 'v1');

      final report = await upgradeProject(project: project, allowDirty: true);
      expect(report.branch, 'bond/upgrade-v2');
    });

    test('refuses a folder that is not a git repository', () async {
      await releaseV2();
      Directory(p.join(project.path, '.git')).deleteSync(recursive: true);

      await expectLater(
        upgradeProject(project: project),
        throwsA(
          isA<UpgradeError>().having(
            (e) => e.message,
            'message',
            contains('not a git repository'),
          ),
        ),
      );
    });

    test('is a no-op at the target version', () async {
      final report = await upgradeProject(project: project);

      expect(report.upToDate, isTrue);
      expect(report.branch, isNull);
      expect(report.describe(), contains('Already at template v1'));
    });

    test('the branch name is taken only once', () async {
      await releaseV2();
      await git(project, ['branch', 'bond/upgrade-v2']);

      await expectLater(
        upgradeProject(project: project),
        throwsA(
          isA<UpgradeError>().having(
            (e) => e.message,
            'message',
            contains('bond/upgrade-v2'),
          ),
        ),
      );
    });
  });

  group('a project without bond.yaml', () {
    setUp(() async {
      File(p.join(project.path, 'bond.yaml')).deleteSync();
      await git(project, ['add', '--all']);
      await git(project, ['commit', '--quiet', '--message', 'old project']);
      await releaseV2();
    });

    test('needs --from', () async {
      await expectLater(
        upgradeProject(project: project, templateUrl: template.url),
        throwsA(
          isA<UpgradeError>().having(
            (e) => e.message,
            'message',
            contains('--from'),
          ),
        ),
      );
    });

    test('detects its names and writes the record', () async {
      final report = await upgradeProject(
        project: project,
        from: 'v1',
        templateUrl: template.url,
      );

      expect(report.added, contains('lib/new_screen.dart'));
      final record = ProjectRecord.read(project)!;
      expect(record.ref, 'v2');
      expect(record.templateUrl, template.url);
      expect(record.identity.name, 'my_app');
      expect(record.identity.appName, 'My App');
      expect(record.identity.bundleId, 'com.acme.app');
      expect(record.identity.applicationId, 'com.acme.app');
    });
  });
}
