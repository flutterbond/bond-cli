import 'package:bond_cli/core/native/flutter_project.dart';
import 'package:test/test.dart';

const _firebaseOptions = '''
  static const FirebaseOptions android = FirebaseOptions(
    projectId: 'flutter-bond-staging',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    projectId: 'flutter-bond-staging',
    iosBundleId: 'ps.app.bond.staging',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    iosBundleId:
        'ps.app.bond.staging',
  );
''';

void main() {
  test('renames the pubspec name and package: imports only', () {
    expect(
      setPubspecName('name: bond\nversion: 2.0.0+1\n', 'acme_shop'),
      'name: acme_shop\nversion: 2.0.0+1\n',
    );
    expect(
      renamePackageUris(
        "import 'package:bond/app/app.dart';\n"
            'export "package:bond/config/configs.dart";\n'
            "import 'package:bond_core/bond_core.dart';\n",
        'bond',
        'acme_shop',
      ),
      "import 'package:acme_shop/app/app.dart';\n"
      'export "package:acme_shop/config/configs.dart";\n'
      "import 'package:bond_core/bond_core.dart';\n",
    );
  });

  test('renames iosBundleId literals, including wrapped ones', () {
    final renamed = renameAppIdLiterals(
      _firebaseOptions,
      oldId: 'ps.app.bond',
      newId: 'com.acme',
      ios: true,
    );

    expect("'com.acme.staging'".allMatches(renamed), hasLength(2));
    expect(renamed, isNot(contains('ps.app.bond')));
  });

  test('renames Android literals but leaves iOS ones alone', () {
    const source =
        "  androidAppBundleId: 'ps.app.bond',\n"
        "  iOSAppBundleId: 'ps.app.bond',\n";

    expect(
      renameAppIdLiterals(
        source,
        oldId: 'ps.app.bond',
        newId: 'com.acme',
        ios: false,
      ),
      "  androidAppBundleId: 'com.acme',\n"
      "  iOSAppBundleId: 'ps.app.bond',\n",
    );
  });
}
