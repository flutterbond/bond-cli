import '../string_extensions.dart';
import 'base_validator.dart';

/// Dart reserved words; none of them can be a class, library or package name.
const dartReservedWords = {
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', //
  'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
  'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
  'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
};

/// Java keywords; Android rejects them as application ID segments.
const _javaKeywords = {
  'abstract', 'assert', 'boolean', 'break', 'byte', 'case', 'catch', //
  'char', 'class', 'const', 'continue', 'default', 'do', 'double', 'else',
  'enum', 'extends', 'false', 'final', 'finally', 'float', 'for', 'goto', 'if',
  'implements', 'import', 'instanceof', 'int', 'interface', 'long', 'native',
  'new', 'null', 'package', 'private', 'protected', 'public', 'return',
  'short', 'static', 'strictfp', 'super', 'switch', 'synchronized', 'this',
  'throw', 'throws', 'transient', 'true', 'try', 'void', 'volatile', 'while',
};

class NonEmptyValidator implements Validator<String> {
  @override
  String? validate(String value) =>
      value.trim().isEmpty ? 'Value is required.' : null;
}

class PascalCaseValidator implements Validator<String> {
  @override
  String? validate(String value) =>
      RegExp(r'^[A-Z][a-zA-Z0-9]*$').hasMatch(value)
      ? null
      : 'Value should be in PascalCase, e.g. User or UserDetail.';
}

class NotReservedWordValidator implements Validator<String> {
  @override
  String? validate(String value) => dartReservedWords.contains(value)
      ? 'Value should not be a Dart reserved word.'
      : null;
}

/// Accepts any input whose snake_case form is a valid Dart package or
/// directory name, e.g. `my_app`, `My App` or `MyApp`.
class SnakeCaseNameValidator implements Validator<String> {
  final String label;

  SnakeCaseNameValidator({this.label = 'Name'});

  @override
  String? validate(String value) {
    final name = value.toSnakeCase();
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      return '$label must start with a letter and contain only letters, '
          'digits, spaces or underscores (got "$name").';
    }
    if (dartReservedWords.contains(name)) {
      return '$label "$name" is a Dart reserved word.';
    }
    return null;
  }
}

class ProjectNameValidator extends SnakeCaseNameValidator {
  ProjectNameValidator() : super(label: 'Project name');
}

/// iOS bundle IDs: alphanumerics, hyphens and periods, at least two segments.
class IosBundleIdValidator implements Validator<String> {
  @override
  String? validate(String value) =>
      RegExp(r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$').hasMatch(value)
      ? null
      : 'Invalid iOS bundle ID: use at least two dot-separated segments '
            'of letters, digits or hyphens, e.g. com.example.app.';
}

/// Android application IDs double as the Kotlin package name, so every
/// segment must be a valid Java identifier.
class AndroidAppIdValidator implements Validator<String> {
  @override
  String? validate(String value) {
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$')
        .hasMatch(value)) {
      return 'Invalid Android application ID: use at least two dot-separated '
          'segments that start with a letter, e.g. com.example.app.';
    }
    final keyword = value.split('.').where(_javaKeywords.contains).firstOrNull;
    if (keyword != null) {
      return 'Invalid Android application ID: "$keyword" is a Java keyword.';
    }
    return null;
  }
}
