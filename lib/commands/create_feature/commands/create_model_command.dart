import 'package:args/command_runner.dart';
import 'package:bond_cli/core/tasks.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/validators.dart';

import '../stubs/model_template.dart';

class CreateModelCommand extends Command<void> with InputResolver {
  @override
  String get name => 'model';

  @override
  String get description => 'Create a new Model.';

  CreateModelCommand() {
    /// Add an option to specify the name of the model.
    argParser
      ..addOption('name', abbr: 'n', help: 'Specify the name of the model.')

      /// Add a flag to specify if the model should be JsonSerializable.
      ..addFlag(
        'jsonSerializable',
        abbr: 'j',
        help: 'Generate code for Json Serialization',
        negatable: false,
      )

      /// Add a flag to specify if the model should be Equatable.
      ..addFlag(
        'equatable',
        abbr: 'e',
        help: 'Make the model equatable',
        negatable: false,
      );
  }

  @override
  Future<void> run() async {
    final isJsonSerializable = argResults?['jsonSerializable'] as bool? ?? true;
    final isEquatable = argResults?['equatable'] as bool? ?? true;
    final modelName = resolveInput(
      'name',
      prompt: 'Enter Model Name:',
      validators: [
        NonEmptyValidator(),
        PascalCaseValidator(),
        NotReservedWordValidator(),
      ],
    );

    await CreateModelTasks(
      modelName: modelName.toSnakeCase(),
      isJsonSerializable: isJsonSerializable,
      isEquatable: isEquatable,
      modelContent: modelStub(
        modelName.toSnakeCase(),
        isJsonSerializable,
        isEquatable,
      ),
    ).run();
  }
}
