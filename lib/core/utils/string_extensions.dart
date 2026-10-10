extension StringExtension on String {
  /// Splits PascalCase, camelCase, snake_case, kebab-case and spaced text into
  /// lowercase words, e.g. `HTTPClientError` -> `[http, client, error]`.
  List<String> get words => trim()
      // Boundary between an acronym and the next word: HTTPClient -> HTTP Client.
      .replaceAllMapped(
        RegExp(r'([A-Z]+)([A-Z][a-z])'),
        (m) => '${m[1]} ${m[2]}',
      )
      // Boundary between a lowercase letter or digit and an uppercase letter.
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .split(RegExp(r'[\s_\-]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word.toLowerCase())
      .toList();

  /// Converts to snake_case, e.g. `UserDetail` -> `user_detail`.
  String toSnakeCase() => words.join('_');

  /// Converts to PascalCase, e.g. `user_detail` -> `UserDetail`.
  String toPascalCase() => words.map((word) => word.toCapitalized()).join();

  /// Converts to space-separated Title Case, e.g. `my_app` -> `My App`.
  String toTitleCase() => words.map((word) => word.toCapitalized()).join(' ');

  /// Capitalizes the first letter of the string.
  String toCapitalized() {
    if (isEmpty) {
      return this;
    }

    return this[0].toUpperCase() + substring(1);
  }
}
