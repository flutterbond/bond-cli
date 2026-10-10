import 'package:args/command_runner.dart';
import 'package:bond_cli/core/tasks.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/validators.dart';

class UpdateIOSBundleIdCommand extends Command<void> with InputResolver {
  @override
  String get name => 'ios_bundle_id';

  @override
  String get description =>
      'Update the iOS bundle ID for each build configuration.';

  UpdateIOSBundleIdCommand() {
    argParser.addOption(
      'bundleId',
      abbr: 'b',
      aliases: ['bundle-id'],
      help: 'Specify the new bundle ID.',
    );
  }

  @override
  Future<void> run() async {
    final projectDirectory = requireFlutterProject();
    final bundleId = resolveInput(
      'bundleId',
      prompt: 'Enter New iOS Bundle ID:',
      validators: [NonEmptyValidator(), IosBundleIdValidator()],
    );

    await UpdateBundleIdTask(
      projectDirectory: projectDirectory,
      bundleId: bundleId,
    ).run();
  }
}
