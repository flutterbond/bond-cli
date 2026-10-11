import 'dart:io';

import 'package:bond_cli/mcp/bond_mcp_server.dart';
import 'package:bond_cli/mcp/packages/bond_package_locator.dart';
import 'package:dart_mcp/client.dart';
import 'package:test/test.dart';

import 'fake_project.dart';
import 'test_environment.dart';

void main() {
  late FakeProject project;

  setUp(() => project = FakeProject.create());
  tearDown(() => project.delete());

  BondMcpServer server(channel, {Directory? fallback}) => BondMcpServer(
    channel,
    projectFallback: fallback,
    locator: BondPackageLocator(pubCacheDir: project.pubCache),
  );

  test('without client roots it answers for --project', () async {
    final env = TestEnvironment(
      PlainClient(),
      (c) => server(c, fallback: Directory(project.root)),
    );
    final init = await env.initialize();

    expect(init.serverInfo.name, 'bond');
    final tools = await env.connection.listTools();
    expect(
      tools.tools.map((t) => t.name),
      containsAll(['packages', 'package_overview', 'migration']),
    );

    final packages = await env.call('packages');
    expect(packages.isError, isNot(true));
    expect(textOf(packages), contains('bond_core 0.1.0 (hosted)'));
    expect(textOf(packages), contains('bond_form 0.1.0 (path)'));
    expect(textOf(packages), isNot(contains('bond_cli')));
  });

  test(
    'with client roots it uses the root that has a package config',
    () async {
      final client = RootsClient()
        ..addRoot(
          Root(uri: Directory.systemTemp.uri.toString(), name: 'no config'),
        )
        ..addRoot(
          Root(uri: Directory(project.root).uri.toString(), name: 'app'),
        );
      final env = TestEnvironment(client, (c) => server(c));
      await env.initialize();

      final overview = await env.call('package_overview', {
        'package': 'bond_core',
      });
      expect(overview.isError, isNot(true));
      expect(
        textOf(overview),
        contains("import 'package:bond_core/bond_core.dart';"),
      );

      final readme = await env.connection.readResource(
        ReadResourceRequest(uri: 'bond://package/bond_core/readme'),
      );
      expect(
        (readme.contents.single as TextResourceContents).text,
        contains('Service providers'),
      );
    },
  );

  test('errors are plain messages', () async {
    final env = TestEnvironment(
      PlainClient(),
      (c) => server(c, fallback: Directory(project.root)),
    );
    await env.initialize();

    final unknown = await env.call('package_overview', {
      'package': 'bond_unknown',
    });
    expect(unknown.isError, isTrue);
    expect(textOf(unknown), contains('bond_unknown is not a dependency'));
    expect(textOf(unknown), contains('bond_core, bond_form'));

    final noConfig = await env.call('packages', {
      'root': Directory.systemTemp.createTempSync().path,
    });
    expect(noConfig.isError, isTrue);
    expect(textOf(noConfig), contains('pub get'));
  });

  test('the migration guides are served as resources', () async {
    final env = TestEnvironment(
      PlainClient(),
      (c) => server(c, fallback: Directory(project.root)),
    );
    await env.initialize();

    final guide = await env.connection.readResource(
      ReadResourceRequest(uri: 'bond://docs/migration/packages'),
    );
    expect(
      (guide.contents.single as TextResourceContents).text,
      contains('bond_*'),
    );
  });
}
