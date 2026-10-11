import 'dart:io';

import 'package:bond_cli/mcp/api/api_outline.dart';
import 'package:bond_cli/mcp/api/api_view.dart';
import 'package:bond_cli/mcp/packages/bond_package_locator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A package exercising every rule of the outline: a barrel with nested
/// exports, show/hide, a part file, private names, docs and @Deprecated.
BondPackage _fixturePackage(Directory root) {
  void write(String path, String content) =>
      File(p.join(root.path, 'lib', path))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

  write('bond_demo.dart', '''
library;

export 'src/services.dart';
export 'src/models.dart' show User;
export 'src/helpers.dart' hide internalHelper;
export 'package:other/other.dart';
''');
  write('src/services.dart', '''
export 'deep/api.dart';

/// Registers services.
///
/// Second paragraph is not shown.
abstract class Service {
  /// Creates the service.
  Service({bool lazy = false, Map<String, int> options = const {}}) : _lazy = lazy;

  final bool _lazy;

  /// The service name.
  final String name = 'demo';

  static const int version = 1;

  /// Registers into [it].
  Future<void> register(Object it);

  bool get isLazy => _lazy;

  void _privateMethod() {}
}

class _Hidden {}
''');
  write('src/deep/api.dart', '''
part 'api.g.dart';

@Deprecated('Use Service')
class OldApi {}

mixin Jsonable on Object {
  Map<String, Object?> toJson();
}

enum Mode { light, dark }

extension StringX on String {
  String get shout => toUpperCase();
}

typedef JsonFactory = Object Function(Map<String, Object?> json);
''');
  write('src/deep/api.g.dart', '''
part of 'api.dart';

String generatedHelper() => '';
''');
  write('src/models.dart', 'class User {}\nclass Admin {}\n');
  write(
    'src/helpers.dart',
    'void publicHelper() {}\nvoid internalHelper() {}\nfinal String appName = "demo";\n',
  );
  return BondPackage(
    name: 'bond_demo',
    version: '1.0.0',
    description: 'Fixture.',
    rootDir: root.path,
    source: PackageSource.path,
  );
}

void main() {
  late Directory root;
  late List<ApiEntry> entries;

  setUp(() {
    root = Directory.systemTemp.createTempSync('bond_api_');
    entries = ApiOutlineExtractor().extract(_fixturePackage(root));
  });
  tearDown(() => root.deleteSync(recursive: true));

  ApiEntry entry(String name) => entries.singleWhere((e) => e.name == name);

  test('follows the export closure with show/hide and part files', () {
    expect(entries.map((e) => e.name).toSet(), {
      'Service',
      'OldApi',
      'Jsonable',
      'Mode',
      'StringX',
      'JsonFactory',
      'generatedHelper',
      'User',
      'publicHelper',
      'appName',
    });
    expect(
      entries.every((e) => e.library == 'package:bond_demo/bond_demo.dart'),
      isTrue,
    );
  });

  test('skips private declarations and members', () {
    expect(entries.map((e) => e.name), isNot(contains('_Hidden')));
    final members = entry('Service').members.map((m) => m.name);
    expect(members, isNot(contains('_privateMethod')));
    expect(members, isNot(contains('_lazy')));
  });

  test('signatures stop at the body and keep parameters', () {
    final service = entry('Service');
    expect(service.kind, 'abstract class');
    expect(service.signature, 'abstract class Service');
    final members = {for (final m in service.members) m.name: m};
    expect(
      members['Service']!.signature,
      'Service({bool lazy = false, Map<String, int> options = const {}})',
    );
    expect(members['register']!.signature, 'Future<void> register(Object it)');
    expect(members['isLazy']!.kind, 'getter');
    expect(members['name']!.signature, 'final String name');
    expect(members['version']!.kind, 'static field');
    expect(
      entry('JsonFactory').signature,
      'typedef JsonFactory = Object Function(Map<String, Object?> json);',
    );
    expect(entry('Mode').members.map((m) => m.name), ['light', 'dark']);
  });

  test('docs are the first paragraph; deprecations are tagged', () {
    expect(entry('Service').doc, 'Registers services.');
    expect(
      entry('Service').members.firstWhere((m) => m.name == 'register').doc,
      'Registers into [it].',
    );
    expect(entry('OldApi').deprecated, isTrue);
    expect(entry('User').deprecated, isFalse);
  });

  test('selectApi pages and finds symbols and members', () {
    final page = selectApi(entries, limit: 3, offset: 3);
    expect(page.entries, hasLength(3));
    expect(page.total, entries.length);
    expect(page.nextOffset(), 6);

    expect(selectApi(entries, symbol: 'User').entries.single.name, 'User');
    final byMember = selectApi(entries, symbol: 'regist').entries.single;
    expect(byMember.name, 'Service');
    expect(byMember.members.map((m) => m.name), ['register']);
  });

  group('a file exported several times', () {
    late Directory diamond;
    late BondPackage package;
    late List<ApiEntry> all;

    setUp(() {
      diamond = Directory.systemTemp.createTempSync('bond_api_diamond_');
      void write(String path, String content) =>
          File(p.join(diamond.path, 'lib', path))
            ..createSync(recursive: true)
            ..writeAsStringSync(content);
      // a.dart is first reached through `show A`, then again unfiltered.
      write(
        'bond_x.dart',
        "export 'src/a.dart' show A;\nexport 'src/all.dart';\n",
      );
      write('src/all.dart', "export 'a.dart';\n");
      write('src/a.dart', 'class A {}\nclass B {}\n');
      write('extra.dart', "export 'src/a.dart' show B;\n");
      package = BondPackage(
        name: 'bond_x',
        version: '1.0.0',
        description: 'Fixture.',
        rootDir: diamond.path,
        source: PackageSource.path,
      );
      all = ApiOutlineExtractor().extract(package);
    });
    tearDown(() => diamond.deleteSync(recursive: true));

    test('a wider export later in the chain still adds its names', () {
      expect(
        [
          for (final e in all)
            if (e.library == 'package:bond_x/bond_x.dart') e.name,
        ],
        ['A', 'B'],
      );
    });

    test('every library lists what it exports; unfiltered, once', () {
      expect(selectApi(all, library: 'extra.dart').entries.map((e) => e.name), [
        'B',
      ]);
      final page = selectApi(all);
      expect(page.entries.map((e) => e.name), ['A', 'B']);
      expect(page.entries.map((e) => e.library).toSet(), {
        'package:bond_x/bond_x.dart',
      });
    });
  });

  test('renderApi stops at the size budget and pages from there', () {
    final package = _fixturePackage(root);
    final page = selectApi(entries);
    final text = renderApi(
      package,
      page,
      detail: ApiDetail.docs,
      members: true,
      maxChars: 900,
    );
    final shown = RegExp(r'^- `', multiLine: true).allMatches(text).length;
    expect(text.length, lessThanOrEqualTo(900));
    expect(shown, inInclusiveRange(1, page.entries.length - 1));
    expect(text, contains('Showing 1-$shown of ${page.total}'));
    expect(text, contains('Next page: offset=$shown.'));
    expect(text, isNot(contains('[Truncated')));
  });
}
