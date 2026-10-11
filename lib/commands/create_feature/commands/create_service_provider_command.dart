import 'package:args/command_runner.dart';
import 'package:bond_cli/core/generators/generators.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/validators.dart';

import 'feature_option.dart';

class CreateServiceProviderCommand extends Command<void>
    with InputResolver, FeatureOption {
  @override
  String get name => 'service_provider';

  @override
  String get description =>
      'Create a bond_core ServiceProvider in lib/features/<feature>/.';

  CreateServiceProviderCommand() {
    argParser.addOption(
      'name',
      abbr: 'n',
      help:
          'Specify the name of the service provider (PascalCase), e.g. '
          'Profile for ProfileServiceProvider.',
    );
    addFeatureOption();
  }

  @override
  Future<void> run() async {
    final projectDirectory = requireFlutterProject();
    final name = resolveInput(
      'name',
      prompt: 'Enter Service Provider Name:',
      validators: [
        NonEmptyValidator(),
        PascalCaseValidator(),
        NotReservedWordValidator(),
      ],
    ).replaceFirst(RegExp(r'ServiceProvider$'), '');
    final feature = resolveFeature(name);

    final result = await generateServiceProvider(
      project: projectDirectory,
      name: name,
      feature: feature,
    );
    reportFollowUp(result);
  }
}
