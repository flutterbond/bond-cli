import 'dart:io';

import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/mcp/bond_mcp_server.dart';
import 'package:dart_mcp/client.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_environment.dart';

void main() {
  late Directory project;

  setUpAll(() => logger.level = Level.quiet);
  setUp(() {
    project = Directory.systemTemp.createTempSync('bond_mcp_gen_');
    File(p.join(project.path, 'pubspec.yaml'))
        .writeAsStringSync('name: demo\n');
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('create_widget writes into the project and reports the file', () async {
    final env = TestEnvironment(
      PlainClient(),
      (c) => BondMcpServer(c, projectFallback: project),
    );
    await env.initialize();

    final result = await env.call('create_widget', {
      'name': 'ProfileCard',
      'feature': 'profile',
    });

    expect(result.isError, isNot(true));
    expect(result.structuredContent?['files'], [
      'lib/features/profile/presentation/widgets/profile_card.dart',
    ]);
    expect(
      File(
        p.join(
          project.path,
          'lib/features/profile/presentation/widgets/profile_card.dart',
        ),
      ).existsSync(),
      isTrue,
    );

    final again = await env.call('create_widget', {
      'name': 'ProfileCard',
      'feature': 'profile',
    });
    expect(again.isError, isTrue);
    expect(textOf(again), contains('already exists'));
  });

  test('writes outside the client roots are refused', () async {
    final elsewhere = Directory.systemTemp.createTempSync('bond_mcp_other_');
    addTearDown(() => elsewhere.deleteSync(recursive: true));
    File(p.join(elsewhere.path, 'pubspec.yaml'))
        .writeAsStringSync('name: other\n');
    final client = RootsClient()
      ..addRoot(Root(uri: project.uri.toString(), name: 'project'));
    final env = TestEnvironment(client, (c) => BondMcpServer(c));
    await env.initialize();

    final result = await env.call('create_service_provider', {
      'name': 'Profile',
      'root': elsewhere.path,
    });

    expect(result.isError, isTrue);
    expect(textOf(result), contains('outside the client roots'));
    expect(Directory(p.join(elsewhere.path, 'lib')).existsSync(), isFalse);
  });

  test('a folder without pubspec.yaml is not a project', () async {
    final empty = Directory.systemTemp.createTempSync('bond_mcp_empty_');
    addTearDown(() => empty.deleteSync(recursive: true));
    final env = TestEnvironment(
      PlainClient(),
      (c) => BondMcpServer(c, projectFallback: empty),
    );
    await env.initialize();

    final result = await env.call('create_model', {'name': 'User'});

    expect(result.isError, isTrue);
    expect(textOf(result), contains('no pubspec.yaml'));
  });
}
