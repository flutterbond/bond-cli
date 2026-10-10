import 'package:args/command_runner.dart';
import 'package:bond_cli/core/tasks/create_feature/create_service_provider_task.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/validators.dart';

import '../stubs/service_provider_template.dart';

class CreateServiceProviderCommand extends Command<void>
    with InputResolver {
  @override
  String get name => 'service_provider';

  @override
  String get description => 'Create a new Service Provider.';

  CreateServiceProviderCommand() {
    argParser.addOption(
      'name',
      abbr: 'n',
      help: 'Specify the name of the service provider.',
    );
  }

  @override
  Future<void> run() async {
    final serviceProviderName = resolveInput(
      'name',
      prompt: 'Enter Service Provider Name:',
      validators: [
        NonEmptyValidator(),
        PascalCaseValidator(),
        NotReservedWordValidator(),
      ],
    );

    await CreateServiceProviderTask(
      serviceProviderName: serviceProviderName,
      serviceProviderContent: serviceProviderStub(serviceProviderName),
    ).run();
  }
}
