import 'dart:io';

import 'package:bond_cli/commands/bond_command_runner.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await BondCommandRunner().runAndReportErrors(arguments);
}
