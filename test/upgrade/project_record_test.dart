import 'dart:io';

import 'package:bond_cli/core/upgrade/project_record.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fake_template.dart';

void main() {
  test('writes plain YAML and reads it back', () {
    final record = ProjectRecord(
      templateUrl: 'https://github.com/flutterbond/flutter-bond.git',
      ref: 'v2.1.0',
      identity: testIdentity,
    );

    expect(record.toYaml(), contains('  ref: v2.1.0\n'));
    expect(record.toYaml(), contains('  appName: "My App"\n'));
    final read = ProjectRecord.parse(record.toYaml());
    expect(read.templateUrl, record.templateUrl);
    expect(read.ref, 'v2.1.0');
    expect(read.identity.name, 'my_app');
    expect(read.identity.appName, 'My App');
    expect(read.identity.bundleId, 'com.acme.app');
    expect(read.withRef('v3.0.0').ref, 'v3.0.0');
  });

  test('quotes values YAML would read as another type', () {
    const identity = ProjectIdentity(
      name: 'my_app',
      appName: 'true',
      bundleId: 'com.acme.app',
      applicationId: 'com.acme.app',
    );
    final yaml = ProjectRecord(
      templateUrl: '/tmp/t',
      ref: '2.1',
      identity: identity,
    ).toYaml();

    final read = ProjectRecord.parse(yaml);
    expect(read.ref, '2.1');
    expect(read.identity.appName, 'true');
  });

  test('read returns null without a bond.yaml and rejects broken ones', () {
    final dir = Directory.systemTemp.createTempSync('bond_record_');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(ProjectRecord.read(dir), isNull);

    File(p.join(dir.path, 'bond.yaml')).writeAsStringSync(
      'template:\n  url: x\n'
      'project:\n  name: a\n  appName: A\n  bundleId: b\n  applicationId: c\n',
    );
    expect(
      () => ProjectRecord.read(dir),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('template.ref'),
        ),
      ),
    );
  });
}
