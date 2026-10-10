import 'package:args/command_runner.dart';
import 'package:bond_cli/core/tasks.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/validators.dart';

class UpdateAppNameCommand extends Command<void> with InputResolver {
  @override
  String get name => 'app_name';

  @override
  String get description => 'Update the app name for iOS and Android.';

  UpdateAppNameCommand() {
    argParser.addOption('name', abbr: 'n', help: 'Specify the new app name.');
  }

  @override
  Future<void> run() async {
    final projectDirectory = requireFlutterProject();
    final appName = resolveInput(
      'name',
      prompt: 'Enter New App Name:',
      validators: [NonEmptyValidator()],
    );

    await UpdateIOSAppNameTaskForIOS(
      projectDirectory: projectDirectory,
      appName: appName,
    ).run();

    await UpdateAppNameTaskForAndroid(
      projectDirectory: projectDirectory,
      appName: appName,
    ).run();
  }
}
