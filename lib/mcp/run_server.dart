import 'dart:async';
import 'dart:io' as io;

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';

import 'bond_mcp_server.dart';

/// Serves [BondMcpServer] over stdin/stdout until the client disconnects.
///
/// stdout carries only JSON-RPC: `print` is redirected to stderr and uncaught
/// errors are logged to the client (or stderr before initialization).
Future<void> runBondMcpServer({
  io.Directory? projectFallback,
  String? logFile,
}) async {
  final protocolLog = logFile == null ? null : io.File(logFile).openWrite();
  BondMcpServer? server;
  runZonedGuarded(
    () {
      server = BondMcpServer(
        stdioChannel(input: io.stdin, output: io.stdout),
        projectFallback: projectFallback,
        protocolLogSink: protocolLog == null ? null : _LineSink(protocolLog),
      );
    },
    (error, stack) {
      final running = server;
      if (running != null && running.ready) {
        running.log(LoggingLevel.error, '$error\n$stack');
      } else {
        io.stderr.writeln('bond mcp: $error\n$stack');
      }
    },
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, line) => io.stderr.writeln(line),
    ),
  );
  await server?.done;
  await protocolLog?.close();
}

/// Writes each protocol message as one line of the `--log-file`.
class _LineSink implements Sink<String> {
  _LineSink(this._sink);

  final io.IOSink _sink;

  @override
  void add(String data) => _sink.writeln(data);

  @override
  void close() {}
}
