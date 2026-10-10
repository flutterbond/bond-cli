String widgetStub(String className, String type) {
  switch (type) {
    case 'stateful':
      return _statefulWidgetStub(className);

    case 'consumer':
      return _consumerWidgetStub(className);

    case 'stateless':
    default:
      return _statelessWidgetStub(className);
  }
}

String _statelessWidgetStub(String name) {
  return '''
import 'package:flutter/material.dart';

class $name extends StatelessWidget {
  const $name({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
''';
}

String _statefulWidgetStub(String name) {
  return '''
import 'package:flutter/material.dart';

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

String _consumerWidgetStub(String name) {
  return '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class $name extends ConsumerWidget {
  const $name({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Placeholder();
  }
}
''';
}
