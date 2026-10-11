import 'dart:async';

import 'package:dart_mcp/client.dart';
import 'package:dart_mcp/server.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// Connects an [MCPClient] to a server in-process (adapted from dart_mcp's own
/// test utilities, which are not part of its public API).
class TestEnvironment<Server extends MCPServer> {
  TestEnvironment(
    this.client,
    Server Function(StreamChannel<String>) createServer,
  ) {
    server = createServer(
      StreamChannel<String>.withCloseGuarantee(
        _toServer.stream,
        _toClient.sink,
      ),
    );
    connection = client.connectServer(
      StreamChannel<String>.withCloseGuarantee(
        _toClient.stream,
        _toServer.sink,
      ),
    );
    addTearDown(() async {
      await client.shutdown();
      await server.shutdown();
    });
  }

  final _toServer = StreamController<String>();
  final _toClient = StreamController<String>();
  final MCPClient client;
  late final Server server;
  late final ServerConnection connection;

  Future<InitializeResult> initialize() async {
    final result = await connection.initialize(
      InitializeRequest(
        protocolVersion: ProtocolVersion.latestSupported,
        capabilities: client.capabilities,
        clientInfo: client.implementation,
      ),
    );
    connection.notifyInitialized(InitializedNotification());
    await server.initialized;
    return result;
  }

  Future<CallToolResult> call(
    String tool, [
    Map<String, Object?> arguments = const {},
  ]) => connection.callTool(CallToolRequest(name: tool, arguments: arguments));
}

base class PlainClient extends MCPClient {
  PlainClient() : super(Implementation(name: 'test client', version: '0.0.0'));
}

base class RootsClient extends MCPClient with RootsSupport {
  RootsClient() : super(Implementation(name: 'roots client', version: '0.0.0'));
}

String textOf(CallToolResult result) =>
    result.content.whereType<TextContent>().map((c) => c.text).join('\n');
