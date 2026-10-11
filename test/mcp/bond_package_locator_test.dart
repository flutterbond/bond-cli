import 'dart:io';

import 'package:bond_cli/mcp/packages/bond_package_locator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fake_project.dart';

void main() {
  late FakeProject project;
  late BondPackageLocator locator;

  setUp(() {
    project = FakeProject.create();
    locator = BondPackageLocator(pubCacheDir: project.pubCache);
  });
  tearDown(() => project.delete());

  test(
    'finds the bond_* packages with version, description and source',
    () async {
      final resolved = await locator.locate(Directory(project.root));

      expect(resolved.packages.map((p) => p.name), ['bond_core', 'bond_form']);
      final core = resolved.find('bond_core')!;
      expect(core.version, '0.1.0');
      expect(core.description, 'Core of Bond.');
      expect(core.source, PackageSource.hosted);
      expect(core.rootDir, p.normalize(project.bondCoreRoot));
      final form = resolved.find('bond_form')!;
      expect(form.source, PackageSource.path);
      expect(form.rootDir, p.normalize(project.bondFormRoot));
      expect(
        resolved.packageConfigPath,
        endsWith(p.join('.dart_tool', 'package_config.json')),
      );
    },
  );

  test('a subfolder (pub workspace member) uses the config above it', () async {
    final member = Directory(p.join(project.root, 'packages', 'member'))
      ..createSync(recursive: true);

    final resolved = await locator.locate(member);

    expect(resolved.projectRoot, p.normalize(project.root));
    expect(resolved.find('bond_core'), isNotNull);
  });

  test('a project without package config asks for pub get', () async {
    final bare = Directory.systemTemp.createTempSync('bond_mcp_bare_');
    addTearDown(() => bare.deleteSync(recursive: true));

    expect(
      () => locator.locate(bare),
      throwsA(
        isA<PackageConfigNotFound>().having(
          (e) => e.toString(),
          'message',
          contains('pub get'),
        ),
      ),
    );
  });
}
