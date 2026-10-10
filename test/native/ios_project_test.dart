import 'dart:io';

import 'package:bond_cli/core/native/ios_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _configurations = [
  'Debug-Production',
  'Release-Production',
  'Profile-Production',
  'Debug-Staging',
  'Release-Staging',
  'Profile-Staging',
];

String _configuration(String id, String name, String settings) =>
    '''
		$id /* $name */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
$settings
				LD_RUNPATH_SEARCH_PATHS = (
					"\$(inherited)",
					"@executable_path/Frameworks",
				);
				PRODUCT_NAME = "\$(TARGET_NAME)";
			};
			name = "$name";
		};
''';

/// A pbxproj with the six Runner configurations of the template, one
/// RunnerTests configuration and a project-level one without a bundle ID.
final _pbxproj = [
  '// !\$*UTF8*\$!\n{\n\tobjects = {\n',
  '/* Begin XCBuildConfiguration section */\n',
  for (final (index, name) in _configurations.indexed)
    _configuration(
      'A$index',
      name,
      '\t\t\t\tAPP_DISPLAY_NAME = "${name.endsWith('Staging') ? 'Bond Staging' : 'Bond'}";\n'
          '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = '
          'ps.app.bond${name.endsWith('Staging') ? '.staging' : ''};',
    ),
  _configuration(
    'B0',
    'Debug-Production',
    '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = ps.app.bond.RunnerTests;',
  ),
  _configuration('C0', 'Debug-Production', '\t\t\t\tSDKROOT = iphoneos;'),
  '/* End XCBuildConfiguration section */\n\t};\n}\n',
].join();

const _infoPlist = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key>
	<string>Bond</string>
	<key>CFBundleName</key>
	<string>bond</string>
</dict>
</plist>
''';

void main() {
  test('renames the bundle ID of the six configurations', () {
    final pbxproj = renameBundleIds(_pbxproj, 'com.acme.shop');
    final ids = readBuildSettings(pbxproj, 'PRODUCT_BUNDLE_IDENTIFIER');

    expect(ids, [
      ('Debug-Production', 'com.acme.shop'),
      ('Release-Production', 'com.acme.shop'),
      ('Profile-Production', 'com.acme.shop'),
      ('Debug-Staging', 'com.acme.shop.staging'),
      ('Release-Staging', 'com.acme.shop.staging'),
      ('Profile-Staging', 'com.acme.shop.staging'),
      ('Debug-Production', 'com.acme.shop.RunnerTests'),
    ]);
    // Nothing but the bundle IDs changed.
    expect(pbxproj, _pbxproj.replaceAll('ps.app.bond', 'com.acme.shop'));
  });

  test('detects the base ID and accepts hyphenated IDs', () {
    expect(detectBaseBundleId(_pbxproj), 'ps.app.bond');
    expect(
      renameBundleIds(_pbxproj, 'com.acme-shop'),
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme-shop.staging;'),
    );
  });

  test('sets CFBundleName and CFBundleDisplayName, escaping XML', () {
    var plist = setPlistString(_infoPlist, 'CFBundleDisplayName', 'Tom & Co');
    plist = setPlistString(plist, 'CFBundleName', 'tom_co');

    expect(readPlistString(plist, 'CFBundleDisplayName'), 'Tom &amp; Co');
    expect(readPlistString(plist, 'CFBundleName'), 'tom_co');
  });

  group('IosProject', () {
    late Directory root;

    File file(String path) => File(p.joinAll([root.path, ...path.split('/')]));

    void write(String path, String content) =>
        (file(path)..createSync(recursive: true)).writeAsStringSync(content);

    String plist(String bundleId) =>
        '<plist>\n<dict>\n\t<key>BUNDLE_ID</key>\n'
        '\t<string>$bundleId</string>\n</dict>\n</plist>\n';

    setUp(() {
      root = Directory.systemTemp.createTempSync('bond_ios_');
      write('ios/Runner.xcodeproj/project.pbxproj', _pbxproj);
      write('ios/Runner/Info.plist', _infoPlist);
      write('ios/Production/GoogleService-Info.plist', plist('ps.app.bond'));
      write(
        'ios/Staging/GoogleService-Info.plist',
        plist('ps.app.bond.staging'),
      );
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('renames the Firebase BUNDLE_ID of each flavor', () {
      expect(IosProject(root).setBundleId('com.acme'), isEmpty);

      expect(
        readPlistString(
          file('ios/Production/GoogleService-Info.plist').readAsStringSync(),
          'BUNDLE_ID',
        ),
        'com.acme',
      );
      expect(
        readPlistString(
          file('ios/Staging/GoogleService-Info.plist').readAsStringSync(),
          'BUNDLE_ID',
        ),
        'com.acme.staging',
      );
    });

    test('renames a display name held in a build setting per flavor', () {
      write(
        'ios/Runner/Info.plist',
        _infoPlist.replaceFirst(
          '<string>Bond</string>',
          r'<string>$(APP_DISPLAY_NAME)</string>',
        ),
      );

      IosProject(root).setAppName(displayName: 'Acme', bundleName: 'acme');

      final pbxproj = file('ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync();
      expect(
        readBuildSettings(pbxproj, 'APP_DISPLAY_NAME').map((s) => s.$2).toSet(),
        {'Acme', 'Acme Staging'},
      );
      expect(pbxproj, contains('APP_DISPLAY_NAME = "Acme Staging";'));
      final info = file('ios/Runner/Info.plist').readAsStringSync();
      expect(
        readPlistString(info, 'CFBundleDisplayName'),
        r'$(APP_DISPLAY_NAME)',
      );
      expect(readPlistString(info, 'CFBundleName'), 'acme');
    });
  });
}
