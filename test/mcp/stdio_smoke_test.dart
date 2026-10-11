@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:test/test.dart';

import 'fake_project.dart';

/// Starts the real `bond mcp` process. Any banner, spinner or log line on
/// stdout would break the JSON-RPC stream, so this guards stdout hygiene.
void main() {
  test('bond mcp speaks only JSON-RPC on stdout', () async {
    final project = FakeProject.create();
    addTearDown(project.delete);

    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/bond.dart',
      'mcp',
      '--project',
      project.root,
    ]);
    final stderrText = StringBuffer();
    process.stderr.transform(utf8.decoder).listen(stderrText.write);

    final client = MCPClient(Implementation(name: 'smoke', version: '0.0.0'));
    final connection = client.connectServer(
      stdioChannel(input: process.stdout, output: process.stdin),
    );
    addTearDown(() async {
      await client.shutdown();
      process.kill();
    });

    final init = await connection.initialize(
      InitializeRequest(
        protocolVersion: ProtocolVersion.latestSupported,
        capabilities: client.capabilities,
        clientInfo: client.implementation,
      ),
    );
    connection.notifyInitialized(InitializedNotification());

    expect(init.serverInfo.name, 'bond');
    final tools = await connection.listTools();
    expect(tools.tools.map((t) => t.name), contains('packages'));
    final packages = await connection.callTool(
      CallToolRequest(name: 'packages'),
    );
    expect(packages.isError, isNot(true));
    expect(stderrText.toString(), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
