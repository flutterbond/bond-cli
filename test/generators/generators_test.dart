import 'dart:io';

import 'package:bond_cli/core/generators/feature_paths.dart';
import 'package:bond_cli/core/generators/generators.dart';
import 'package:bond_cli/core/utils.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;

  setUpAll(() => logger.level = Level.quiet);
  setUp(() {
    project = Directory.systemTemp.createTempSync('bond_gen_');
    File(
      p.join(project.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: demo\ndependencies:\n  material_ui: ^1.6.0\n');
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('FeaturePaths', () {
    final model = FeaturePaths.model('profile', 'UserDetail');
    expect(model, 'lib/features/profile/data/models/user_detail.dart');
    expect(
      FeaturePaths.generatedPart(model),
      'lib/features/profile/data/models/user_detail.g.dart',
    );
    expect(
      FeaturePaths.widget('profile', 'ProfileCard'),
      'lib/features/profile/presentation/widgets/profile_card.dart',
    );
    expect(
      FeaturePaths.serviceProvider('profile', 'ProfileServiceProvider'),
      'lib/features/profile/profile_service_provider.dart',
    );
  });

  test('generators return the created files and the follow-up', () async {
    final model = await generateModel(
      project: project,
      name: 'UserDetail',
      feature: 'profile',
    );
    expect(model.files, ['lib/features/profile/data/models/user_detail.dart']);
    expect(model.followUp.single, contains('build_runner'));

    final widget = await generateWidget(
      project: project,
      name: 'ProfileCard',
      type: 'consumer',
      feature: 'profile',
    );
    final widgetFile = File(p.join(project.path, widget.files.single));
    expect(
      widgetFile.readAsStringSync(),
      contains('package:material_ui/material_ui.dart'),
    );

    final provider = await generateServiceProvider(
      project: project,
      name: 'ProfileServiceProvider',
    );
    expect(provider.files, [
      'lib/features/profile/profile_service_provider.dart',
    ]);
    expect(provider.followUp.single, contains('ProfileServiceProvider()'));

    for (final result in [model, widget, provider]) {
      expect(
        File(p.join(project.path, result.files.first)).existsSync(),
        isTrue,
      );
    }
  });

  test('existing files are never overwritten', () async {
    await generateWidget(project: project, name: 'Card');
    await expectLater(
      generateWidget(project: project, name: 'Card'),
      throwsA(predicate((e) => '$e'.contains('already exists'))),
    );
  });

  test('invalid input is rejected with a readable message', () {
    expect(
      () => generateModel(project: project, name: 'user_detail'),
      throwsA(
        isA<GeneratorInputError>().having(
          (e) => e.message,
          'message',
          contains('PascalCase'),
        ),
      ),
    );
    expect(
      () => generateWidget(project: project, name: 'Card', type: 'fancy'),
      throwsA(isA<GeneratorInputError>()),
    );
    expect(resolveFeatureName('UserProfile', 'Ignored'), 'user_profile');
    expect(resolveFeatureName(null, 'UserDetail'), 'user_detail');
    expect(projectDisplayName('my_app'), 'My App');
  });
}
