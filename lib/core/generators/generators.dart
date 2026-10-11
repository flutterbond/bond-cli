import 'dart:io';

import 'package:bond_cli/commands/create_feature/stubs/model_template.dart';
import 'package:bond_cli/commands/create_feature/stubs/service_provider_template.dart';
import 'package:bond_cli/commands/create_feature/stubs/widget_template.dart';
import 'package:bond_cli/core/native/flutter_project.dart';
import 'package:bond_cli/core/tasks.dart';
import 'package:bond_cli/core/tasks/create_feature/create_service_provider_task.dart';
import 'package:bond_cli/core/tasks/create_feature/create_widget_task.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/upgrade/project_record.dart';
import 'package:bond_cli/core/upgrade/template_snapshot.dart';
import 'package:bond_cli/core/validators.dart';
import 'package:path/path.dart' as p;

import 'feature_paths.dart';

/// What a generator created and what the developer still has to do.
class GeneratorResult {
  const GeneratorResult({required this.files, this.followUp = const []});

  /// Created paths, relative to the project root (or the new project's path
  /// for [generateProject]).
  final List<String> files;
  final List<String> followUp;

  Map<String, Object?> toJson() => {'files': files, 'followUp': followUp};
}

/// Invalid generator input; the message says what to change.
class GeneratorInputError implements Exception {
  GeneratorInputError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The flutter-bond template `create project` clones by default.
const defaultTemplateUrl = 'https://github.com/flutterbond/flutter-bond.git';
const defaultTemplateRef = 'v2.1.0';

/// The widget kinds `create widget` supports.
const widgetTypes = ['stateless', 'stateful', 'consumer'];

/// Creates a json_serializable model in `lib/features/<feature>/data/models/`.
Future<GeneratorResult> generateModel({
  required Directory project,
  required String name,
  String? feature,
  bool runBuildRunner = false,
}) async {
  _validate(name, 'Model name', [
    NonEmptyValidator(),
    PascalCaseValidator(),
    NotReservedWordValidator(),
  ]);
  final featureName = resolveFeatureName(feature, name);
  final path = FeaturePaths.model(featureName, name);
  await CreateModelTasks(
    projectDirectory: project,
    modelName: name,
    feature: featureName,
    modelContent: modelStub(name),
    runBuildRunner: runBuildRunner,
  ).run();
  final part = FeaturePaths.generatedPart(path);
  return GeneratorResult(
    files: [path, if (runBuildRunner) part],
    followUp: [
      if (!runBuildRunner)
        'Run `dart run build_runner build` to generate $part.',
    ],
  );
}

/// Creates a widget in `lib/features/<feature>/presentation/widgets/`.
Future<GeneratorResult> generateWidget({
  required Directory project,
  required String name,
  String type = 'stateless',
  String? feature,
}) async {
  _validate(name, 'Widget name', [NonEmptyValidator(), PascalCaseValidator()]);
  if (!widgetTypes.contains(type)) {
    throw GeneratorInputError(
      'Widget type must be one of ${widgetTypes.join(', ')}.',
    );
  }
  final featureName = resolveFeatureName(feature, name);
  await CreateWidgetTask(
    projectDirectory: project,
    widgetName: name,
    feature: featureName,
    widgetContent: widgetStub(
      name,
      type,
      materialUi: FlutterProject(project).dependsOn('material_ui'),
    ),
  ).run();
  return GeneratorResult(files: [FeaturePaths.widget(featureName, name)]);
}

/// Creates a bond_core ServiceProvider in `lib/features/<feature>/`.
/// [name] may end with `ServiceProvider` (`Profile` and `ProfileServiceProvider`
/// both create `ProfileServiceProvider`).
Future<GeneratorResult> generateServiceProvider({
  required Directory project,
  required String name,
  String? feature,
}) async {
  _validate(name, 'Service provider name', [
    NonEmptyValidator(),
    PascalCaseValidator(),
    NotReservedWordValidator(),
  ]);
  final baseName = name.replaceFirst(RegExp(r'ServiceProvider$'), '');
  final featureName = resolveFeatureName(feature, baseName);
  final className = '${baseName}ServiceProvider';
  await CreateServiceProviderTask(
    projectDirectory: project,
    serviceProviderName: className,
    feature: featureName,
    serviceProviderContent: serviceProviderStub(className),
  ).run();
  return GeneratorResult(
    files: [FeaturePaths.serviceProvider(featureName, className)],
    followUp: [
      'Add $className() to the providers list in lib/app/app.dart to register it.',
    ],
  );
}

/// Creates a project from the flutter-bond template in `<parent>/<project_name>`.
Future<GeneratorResult> generateProject({
  required Directory parent,
  required String projectName,
  required String bundleId,
  String? applicationId,
  String? appName,
  required String templateUrl,
  required String ref,
  bool pubGet = true,
}) async {
  _validate(projectName, 'Project name', [
    NonEmptyValidator(),
    ProjectNameValidator(),
  ]);
  _validate(bundleId, 'iOS bundle ID', [IosBundleIdValidator()]);
  final androidId = applicationId ?? bundleId;
  _validate(androidId, 'Android application ID', [AndroidAppIdValidator()]);

  final snakeName = projectName.toSnakeCase();
  final identity = ProjectIdentity(
    name: snakeName,
    appName: appName ?? projectDisplayName(projectName),
    bundleId: bundleId,
    applicationId: androidId,
  );
  final directory = Directory(p.join(parent.path, snakeName));

  await renderTemplate(
    directory: directory,
    templateUrl: templateUrl,
    ref: ref,
    identity: identity,
    pubGet: pubGet,
  );
  ProjectRecord(
    templateUrl: templateUrl,
    ref: ref,
    identity: identity,
  ).write(directory);
  await InitGitRepositoryTask(
    directory: directory,
    message: 'Initial commit from flutter-bond $ref',
  ).run();

  return GeneratorResult(
    files: [directory.path],
    followUp: [
      if (!pubGet) 'Run `flutter pub get` in ${directory.path}.',
      'Create env.staging.json and env.json from env.example.json.',
    ],
  );
}

/// The feature folder: [feature] in snake_case, or [name] in snake_case.
String resolveFeatureName(String? feature, String name) {
  final value = (feature == null || feature.isEmpty ? name : feature)
      .toSnakeCase();
  _validate(value, 'Feature', [SnakeCaseNameValidator(label: 'Feature')]);
  return value;
}

/// `my_app` -> `My App`; names typed with spaces or capitals are kept.
String projectDisplayName(String projectName) {
  final trimmed = projectName.trim();
  return trimmed.contains(RegExp(r'[\sA-Z]')) ? trimmed : trimmed.toTitleCase();
}

void _validate(String value, String label, List<Validator<String>> validators) {
  final error = CompositeValidator(validators).validate(value);
  if (error != null) throw GeneratorInputError('$label "$value": $error');
}
