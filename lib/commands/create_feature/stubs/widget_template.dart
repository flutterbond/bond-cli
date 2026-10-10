/// Projects that depend on material_ui (the v2 template) import it instead
/// of `package:flutter/material.dart`; it re-exports the widgets library.
String widgetStub(String className, String type, {bool materialUi = false}) {
  final materialImport = materialUi
      ? "import 'package:material_ui/material_ui.dart';"
      : "import 'package:flutter/material.dart';";
  return switch (type) {
    'stateful' => _statefulWidgetStub(className, materialImport),
    'consumer' => _consumerWidgetStub(className, materialImport),
    _ => _statelessWidgetStub(className, materialImport),
  };
}

String _statelessWidgetStub(String name, String materialImport) {
  return '''
$materialImport

class $name extends StatelessWidget {
  const $name({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
''';
}

String _statefulWidgetStub(String name, String materialImport) {
  return '''
$materialImport

class $name extends StatefulWidget {
  const $name({super.key});

  @override
  State<$name> createState() => _${name}State();
}

class _${name}State extends State<$name> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
''';
}

String _consumerWidgetStub(String name, String materialImport) {
  final imports = [
    materialImport,
    "import 'package:flutter_riverpod/flutter_riverpod.dart';",
  ]..sort();
  return '''
${imports.join('\n')}

class $name extends ConsumerWidget {
  const $name({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Placeholder();
  }
}
''';
}
