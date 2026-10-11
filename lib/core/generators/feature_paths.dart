import 'package:bond_cli/core/utils.dart';
import 'package:path/path.dart' as p;

/// Where the generators write files: posix paths relative to the project root.
abstract final class FeaturePaths {
  /// `lib/features/<feature>/data/models/<model>.dart`
  static String model(String feature, String modelName) => p.posix.join(
    'lib',
    'features',
    feature,
    'data',
    'models',
    '${modelName.toSnakeCase()}.dart',
  );

  /// The json_serializable part of [modelPath]: `<model>.g.dart`.
  static String generatedPart(String modelPath) =>
      '${p.posix.withoutExtension(modelPath)}.g.dart';

  /// `lib/features/<feature>/presentation/widgets/<widget>.dart`
  static String widget(String feature, String widgetName) => p.posix.join(
    'lib',
    'features',
    feature,
    'presentation',
    'widgets',
    '${widgetName.toSnakeCase()}.dart',
  );

  /// `lib/features/<feature>/<class>.dart`, e.g. `profile_service_provider.dart`.
  static String serviceProvider(String feature, String className) => p.posix
      .join('lib', 'features', feature, '${className.toSnakeCase()}.dart');
}
