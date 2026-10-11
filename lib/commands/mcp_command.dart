import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/mcp/run_server.dart';
import 'package:mason_logger/mason_logger.dart';

/// `bond mcp`: runs the Bond MCP server over stdio for AI coding agents.
class McpCommand extends Command<void> {
  McpCommand() {
    argParser
      ..addOption(
        'project',
        valueHelp: 'dir',
        help:
            'Project to answer for when the client reports no roots '
            '(default: the current directory).',
      )
      ..addOption(
        'log-file',
        valueHelp: 'path',
        help: 'Write every MCP protocol message to this file (debugging).',
      );
  }

  static const commandName = 'mcp';

  @override
  String get name => commandName;

  @override
  String get description =>
      'Start the Bond MCP server (stdio) that teaches AI coding agents such as '
      'Claude Code the bond_* packages of a project.';

  @override
  Future<void> run() async {
    final logFile = argResults!['log-file'] as String?;
    if (logFile != null) {
      try {
        File(logFile).writeAsStringSync('');
      } on FileSystemException catch (error) {
        usageException(
          'Cannot write --log-file $logFile: '
          '${error.osError?.message ?? error.message}',
        );
      }
    }
    // stdout is the JSON-RPC channel: no banner, spinner or log line may reach it.
    logger.level = Level.quiet;
    final project = argResults!['project'] as String?;
    await runBondMcpServer(
      projectFallback: project == null ? null : Directory(project),
      logFile: logFile,
    );
  }
}
