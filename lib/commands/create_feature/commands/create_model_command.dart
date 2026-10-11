import 'package:args/command_runner.dart';
import 'package:bond_cli/core/generators/generators.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/validators.dart';

import 'feature_option.dart';

class CreateModelCommand extends Command<void>
    with InputResolver, FeatureOption {
  @override
  String get name => 'model';

  @override
  String get description =>
      'Create a json_serializable model in lib/features/<feature>/data/models/.';

  CreateModelCommand() {
    argParser.addOption(
      'name',
      abbr: 'n',
      help: 'Specify the name of the model (PascalCase).',
    );
    addFeatureOption();
    argParser
      ..addFlag(
        'build-runner',
        help: 'Run build_runner to generate the .g.dart part.',
        defaultsTo: true,
      )
      // Models are always json_serializable and Equatable (through Model)
      // now; the old flags are accepted and ignored.
      ..addFlag('jsonSerializable', abbr: 'j', negatable: false, hide: true)
      ..addFlag('equatable', abbr: 'e', negatable: false, hide: true);
  }

  @override
  Future<void> run() async {
    final projectDirectory = requireFlutterProject();
    final modelName = resolveInput(
      'name',
      prompt: 'Enter Model Name:',
      validators: [
        NonEmptyValidator(),
        PascalCaseValidator(),
        NotReservedWordValidator(),
      ],
    );
    final feature = resolveFeature(modelName);

    final result = await generateModel(
      project: projectDirectory,
      name: modelName,
      feature: feature,
      runBuildRunner: argResults!['build-runner'] as bool,
    );
    reportFollowUp(result);
  }
}
