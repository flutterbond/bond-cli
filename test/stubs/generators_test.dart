import 'dart:io';

import 'package:bond_cli/commands/create_feature/stubs/model_template.dart';
import 'package:bond_cli/commands/create_feature/stubs/service_provider_template.dart';
import 'package:bond_cli/commands/create_feature/stubs/widget_template.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Minimal stand-ins with the bond_core / bond_network 0.1.0 signatures the
/// stubs use. The real packages need Flutter, which `dart analyze` lacks.
const _fakePackages = {
  'bond_core': (
    dependencies: 'get_it: ^9.3.0',
    library: '''
import 'package:get_it/get_it.dart';

abstract class ServiceProvider {
  Future<void> register(GetIt it);
}

typedef JsonFactory<T> = T Function(Map<String, dynamic> json);

mixin ResponseDecoding {
  Map<Type, JsonFactory> get factories;
}

mixin Jsonable {
  Map<String, dynamic> toJson();
}
''',
  ),
  'bond_network': (
    dependencies: 'equatable: ^3.0.0\n  bond_core:\n    path: ../bond_core',
    library: '''
import 'package:bond_core/bond_core.dart';
import 'package:equatable/equatable.dart';

abstract class Model extends Equatable with Jsonable {
  const Model({required this.id});

  final int id;

  @override
  List<Object?> get props => [id];
}
''',
  ),
};

const _appPubspec = '''
name: app
publish_to: none
environment:
  sdk: ^3.13.0
dependencies:
  bond_core:
    path: ../bond_core
  bond_network:
    path: ../bond_network
  get_it: ^9.3.0
  json_annotation: ^4.12.0
dev_dependencies:
  lints: ^6.1.0
''';

/// What json_serializable 6.x generates for the stub. build_runner itself is
/// too slow for a unit test (minutes on a cold cache); the V5 end-to-end run
/// executes it through `bond create model` in a generated app.
const _generatedPart = '''
part of 'user_detail.dart';

UserDetail _\$UserDetailFromJson(Map<String, dynamic> json) =>
    UserDetail(id: (json['id'] as num).toInt());

Map<String, dynamic> _\$UserDetailToJson(UserDetail instance) =>
    <String, dynamic>{'id': instance.id};
''';

void main() {
  test('model stub is a complete json_serializable Model', () {
    final stub = modelStub('UserDetail');

    expect(stub, contains("part 'user_detail.g.dart';"));
    expect(stub, contains('@JsonSerializable()'));
    expect(stub, contains('class UserDetail extends Model'));
    expect(stub, contains(r'_$UserDetailFromJson(json)'));
    expect(stub, contains(r'_$UserDetailToJson(this)'));
  });

  test('widget stubs use flutter_riverpod, and material_ui if present', () {
    final stub = widgetStub('UserCard', 'consumer');

    expect(
      stub,
      contains("import 'package:flutter_riverpod/flutter_riverpod.dart';"),
    );
    expect(stub, contains('class UserCard extends ConsumerWidget'));
    expect(stub, isNot(contains('hooks_riverpod')));
    expect(
      widgetStub('UserCard', 'stateless', materialUi: true),
      allOf(
        contains("import 'package:material_ui/material_ui.dart';"),
        isNot(contains('package:flutter/material.dart')),
      ),
    );
  });

  test('service provider stub implements the bond_core 0.1.0 API', () {
    final stub = serviceProviderStub('ProfileServiceProvider');

    expect(
      stub,
      contains(
        'class ProfileServiceProvider extends ServiceProvider '
        'with ResponseDecoding',
      ),
    );
    expect(stub, contains('Future<void> register(GetIt it) async'));
    expect(stub, contains('Map<Type, JsonFactory> get factories'));
  });

  test('generated model and service provider pass dart analyze', () async {
    final temp = Directory.systemTemp.createTempSync('bond_stubs_');
    addTearDown(() => temp.deleteSync(recursive: true));
    void write(String path, String content) => (File(
      p.join(temp.path, path),
    )..createSync(recursive: true)).writeAsStringSync(content);

    for (final MapEntry(key: name, value: package) in _fakePackages.entries) {
      write(
        '$name/pubspec.yaml',
        'name: $name\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\n'
            'dependencies:\n  ${package.dependencies}\n',
      );
      write('$name/lib/$name.dart', package.library);
    }
    const modelPath = 'lib/features/user_detail/data/models/user_detail.dart';
    write('app/pubspec.yaml', _appPubspec);
    write(
      'app/analysis_options.yaml',
      'include: package:lints/recommended.yaml\n',
    );
    write('app/$modelPath', modelStub('UserDetail'));
    write('app/${p.withoutExtension(modelPath)}.g.dart', _generatedPart);
    write(
      'app/lib/features/profile/profile_service_provider.dart',
      serviceProviderStub('ProfileServiceProvider'),
    );

    final app = p.join(temp.path, 'app');
    final dart = Platform.resolvedExecutable;
    Future<ProcessResult> run(List<String> args) =>
        Process.run(dart, args, workingDirectory: app);

    var pubGet = await run(['pub', 'get', '--offline']);
    if (pubGet.exitCode != 0) pubGet = await run(['pub', 'get']);
    if (pubGet.exitCode != 0) {
      markTestSkipped('pub get failed (offline?): ${pubGet.stderr}');
      return;
    }

    final analyze = await run(['analyze', '--fatal-infos']);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
