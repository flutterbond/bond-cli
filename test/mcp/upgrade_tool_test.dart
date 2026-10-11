import 'dart:io';

import 'package:bond_cli/core/upgrade/project_record.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/mcp/bond_mcp_server.dart';
import 'package:dart_mcp/client.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../upgrade/fake_template.dart';
import 'test_environment.dart';

void main() {
  late FakeTemplate template;
  late Directory workspace;
  late Directory project;

  setUpAll(() => logger.level = Level.quiet);
  setUp(() async {
    template = await FakeTemplate.create();
    await template.release('v1', files: FakeTemplate.baseFiles());
    workspace = Directory.systemTemp.createTempSync('bond_mcp_upgrade_');
    project = await createProject(template, workspace);
    await template.release(
      'v2',
      files: {'lib/new_screen.dart': '// new in v2\n'},
    );
  });
  tearDown(() {
    template.dispose();
    workspace.deleteSync(recursive: true);
  });

  Future<TestEnvironment<BondMcpServer>> connect(MCPClient client) async {
    final env = TestEnvironment(
      client,
      (c) => BondMcpServer(c, projectFallback: project),
    );
    await env.initialize();
    return env;
  }

  test('is listed as a destructive tool', () async {
    final env = await connect(PlainClient());

    final tool = (await env.connection.listTools(ListToolsRequest())).tools
        .singleWhere((t) => t.name == 'upgrade_template');

    expect(tool.toolAnnotations?.destructiveHint, isTrue);
    expect(tool.inputSchema.properties, contains('dryRun'));
  });

  test('reports by default and writes nothing', () async {
    final env = await connect(PlainClient());

    final result = await env.call('upgrade_template');

    expect(result.isError, isNot(true));
    expect(
      textOf(result),
      contains('Would upgrade the template files v1 -> v2'),
    );
    expect(result.structuredContent?['dryRun'], isTrue);
    expect(result.structuredContent?['added'], ['lib/new_screen.dart']);
    expect(
      File(p.join(project.path, 'lib/new_screen.dart')).existsSync(),
      isFalse,
    );
    expect(ProjectRecord.read(project)!.ref, 'v1');
  });

  test('dryRun: false upgrades on a branch', () async {
    final env = await connect(PlainClient());

    final result = await env.call('upgrade_template', {'dryRun': false});

    expect(result.isError, isNot(true));
    expect(result.structuredContent?['branch'], 'bond/upgrade-v2');
    expect(
      File(p.join(project.path, 'lib/new_screen.dart')).existsSync(),
      isTrue,
    );
    expect(
      (await git(project, ['branch', '--show-current'])).trim(),
      'bond/upgrade-v2',
    );
  });

  test('explains what to do when the work tree is dirty', () async {
    File(p.join(project.path, 'lib/home.dart')).writeAsStringSync('// dirty\n');
    final env = await connect(PlainClient());

    final result = await env.call('upgrade_template', {'dryRun': false});

    expect(result.isError, isTrue);
    expect(textOf(result), contains('uncommitted changes'));
  });

  test('refuses projects outside the client roots', () async {
    final other = Directory.systemTemp.createTempSync('bond_mcp_other_');
    addTearDown(() => other.deleteSync(recursive: true));
    File(p.join(other.path, 'pubspec.yaml')).writeAsStringSync('name: other\n');
    final client = RootsClient()
      ..addRoot(Root(uri: workspace.uri.toString(), name: 'workspace'));
    final env = TestEnvironment(client, (c) => BondMcpServer(c));
    await env.initialize();

    final result = await env.call('upgrade_template', {'root': other.path});

    expect(result.isError, isTrue);
    expect(textOf(result), contains('outside the client roots'));
  });

  test('a relative local templateUrl is rejected', () async {
    final env = await connect(PlainClient());

    final result = await env.call('upgrade_template', {'templateUrl': '.'});

    expect(result.isError, isTrue);
    expect(textOf(result), contains('must be an absolute path'));
  });
}
