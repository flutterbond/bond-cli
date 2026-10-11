import 'package:bond_cli/core/generators/generators.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:bond_cli/core/validators.dart';

/// The `--feature` option shared by the generators: files go to
/// `lib/features/<feature>/`.
mixin FeatureOption<T> on InputResolver<T> {
  void addFeatureOption() {
    argParser.addOption(
      'feature',
      abbr: 'f',
      help:
          'Feature folder under lib/features/ (converted to snake_case). '
          'Defaults to the snake_case name.',
    );
  }

  /// Returns the snake_case feature, defaulting to [name] in snake_case.
  /// Prints what the developer still has to do after a generator ran.
  void reportFollowUp(GeneratorResult result) {
    for (final line in result.followUp) {
      logger.info(line);
    }
  }

  String resolveFeature(String name) {
    final defaultFeature = name.toSnakeCase();
    return resolveInput(
      'feature',
      prompt: 'Enter Feature Name:',
      defaultValue: defaultFeature,
      fallback: defaultFeature,
      validators: [SnakeCaseNameValidator(label: 'Feature')],
    ).toSnakeCase();
  }
}
