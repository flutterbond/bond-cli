import 'package:args/command_runner.dart';
import 'package:bond_cli/core/tasks.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/validators.dart';

class UpdateApplicationIdCommand extends Command<void> with InputResolver {
  @override
  String get name => 'android_app_id';

  @override
  String get description =>
      'Update the Android application ID, namespace and Kotlin package.';

  UpdateApplicationIdCommand() {
    argParser.addOption(
      'applicationId',
      abbr: 'a',
      aliases: ['application-id'],
      help: 'Specify the new Android application ID.',
    );
  }

  @override
  Future<void> run() async {
    final projectDirectory = requireFlutterProject();
    final applicationId = resolveInput(
      'applicationId',
      prompt: 'Enter New Android Application ID:',
      validators: [NonEmptyValidator(), AndroidAppIdValidator()],
    );

    await UpdateApplicationIdTask(
      projectDirectory: projectDirectory,
      applicationId: applicationId,
    ).run();
  }
}
