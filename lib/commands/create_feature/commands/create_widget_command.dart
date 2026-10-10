import 'package:args/command_runner.dart';
import 'package:bond_cli/core/native/flutter_project.dart';
import 'package:bond_cli/core/tasks/create_feature/create_widget_task.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/validators.dart';

import '../stubs/widget_template.dart';
import 'feature_option.dart';

class CreateWidgetCommand extends Command<void>
    with InputResolver, FeatureOption {
  @override
  String get name => 'widget';

  @override
  String get description =>
      'Create a widget in lib/features/<feature>/presentation/widgets/.';

  CreateWidgetCommand() {
    argParser
      ..addOption(
        'name',
        abbr: 'n',
        help: 'Specify the name of the widget (PascalCase).',
      )
      ..addOption(
        'type',
        abbr: 't',
        help: 'Specify the type of the widget; consumer uses flutter_riverpod.',
        allowed: ['stateless', 'stateful', 'consumer'],
        defaultsTo: 'stateless',
      );
    addFeatureOption();
  }

  @override
  Future<void> run() async {
    final projectDirectory = requireFlutterProject();
    final widgetType = argResults!['type'] as String;
    final widgetName = resolveInput(
      'name',
      prompt: 'Enter Widget Name:',
      validators: [NonEmptyValidator(), PascalCaseValidator()],
    );
    final feature = resolveFeature(widgetName);

    await CreateWidgetTask(
      projectDirectory: projectDirectory,
      widgetName: widgetName,
      feature: feature,
      widgetContent: widgetStub(
        widgetName,
        widgetType,
        materialUi: FlutterProject(projectDirectory).dependsOn('material_ui'),
      ),
    ).run();
  }
}
