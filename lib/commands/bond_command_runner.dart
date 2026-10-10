import 'package:args/command_runner.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:mason_logger/mason_logger.dart';

import 'add_command.dart';
import 'create_command.dart';
import 'update_command.dart';

class BondCommandRunner extends CommandRunner<void> {
  BondCommandRunner()
    : super(
        'bond',
        'A CLI tool for efficient Flutter Bond app development, streamlining tasks like project setup and package management.',
      ) {
    addCommand(CreateCommand());
    addCommand(UpdateCommand());
    addCommand(AddCommand());
  }

  static const _asciiArt = '''
 ____   ___  _   _ ____
| __ ) / _ \\| \\ | |  _ \\
|  _ \\| | | |  \\| | | | |
| |_) | |_| | |\\  | |_| |
|____/ \\___/|_| \\_|____/
''';

  static const _message =
      'Info from https://github.com/flutterbond/flutter-bond: #FreePalestine 🇵🇸\n';

  /// Runs the CLI and returns the process exit code instead of throwing.
  Future<int> runAndReportErrors(Iterable<String> args) async {
    try {
      final argResults = parse(args);
      logger
        ..info(lightCyan.wrap(_asciiArt))
        ..info(lightCyan.wrap(_message));
      await runCommand(argResults);
      return ExitCode.success.code;
    } on UsageException catch (error) {
      logger
        ..err(error.message)
        ..info('')
        ..info(error.usage);
      return ExitCode.usage.code;
    } catch (error) {
      logger.err('$error');
      return ExitCode.software.code;
    }
  }
}
