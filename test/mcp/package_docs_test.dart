import 'dart:io';

import 'package:bond_cli/mcp/docs/changelog.dart';
import 'package:bond_cli/mcp/docs/package_docs.dart';
import 'package:bond_cli/mcp/packages/bond_package_locator.dart';
import 'package:test/test.dart';

import 'fake_project.dart';

void main() {
  group('changelog', () {
    const changelog =
        '# Changelog\n\n## 0.1.0\n\n- New.\n\n## 0.0.22+19\n\n- Old.\n\n## 0.0.4+\n\n- Odd.\n';

    test('splits sections newest first', () {
      expect(parseChangelog(changelog).map((s) => s.version), [
        '0.1.0',
        '0.0.22+19',
        '0.0.4+',
      ]);
      expect(latestSections(changelog, 1).single.text, '## 0.1.0\n\n- New.');
    });

    test('selects the sections between two versions', () {
      expect(
        sectionsBetween(changelog, from: '0.0.22+19').map((s) => s.version),
        ['0.1.0'],
      );
      expect(
        sectionsBetween(changelog, to: '0.0.22+19').map((s) => s.version),
        ['0.0.22+19'],
      );
    });
  });

  group('package documents', () {
    late FakeProject project;
    late ResolvedBondPackages resolved;

    setUp(() async {
      project = FakeProject.create();
      resolved = await BondPackageLocator(pubCacheDir: project.pubCache)
          .locate(Directory(project.root));
    });
    tearDown(() => project.delete());

    test('public libraries exclude lib/src and generated parts', () {
      expect(publicLibraries(resolved.find('bond_form')!), [
        'package:bond_form/bond_form.dart',
        'package:bond_form/validator_localizations.dart',
      ]);
    });

    test('the overview has the import, README, example and latest change', () {
      final overview = packageOverview(
        resolved.find('bond_core')!,
        changelogSections: 1,
      );

      expect(overview, contains("import 'package:bond_core/bond_core.dart';"));
      expect(overview, contains('Service providers and `sl`.'));
      expect(overview, contains('void main() {}'));
      expect(overview, contains('material_ui types'));
      expect(overview, isNot(contains('- Old.')));
    });

    test(
      'migration notes combine the guide section and the CHANGELOG range',
      () {
        final notes = migrationNotes(
          package: resolved.find('bond_form')!,
          from: '0.0.22+19',
        );

        expect(notes, contains('### bond_form'));
        expect(notes, contains('dateAfter fix'));
        expect(notes, isNot(contains('- Older.')));
      },
    );

    test('long answers are truncated with a hint', () {
      final text = truncate('x' * 50, maxChars: 10);
      expect(text, startsWith('xxxxxxxxxx'));
      expect(text, contains('Truncated: 40 more characters'));
    });
  });
}
