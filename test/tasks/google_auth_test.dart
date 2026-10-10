import 'package:bond_cli/core/tasks/auth/google/integrate_ios_task.dart';
import 'package:test/test.dart';

const _plist = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>bond</string>
</dict>
</plist>
''';

const _plistWithUrlTypes = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>bond</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
''';

void main() {
  test('adds the Google Sign-In keys once', () {
    final once = addGoogleSignInToInfoPlist(_plist);

    expect(addGoogleSignInToInfoPlist(once), once);
    expect('<key>CFBundleURLTypes</key>'.allMatches(once), hasLength(1));
    expect(once, contains(r'<string>$(GOOGLE_REVERSED_CLIENT_ID)</string>'));
    expect(once, contains('<key>GIDClientID</key>'));
    expect(once, endsWith('</dict>\n</plist>\n'));
  });

  test('appends the URL scheme to an existing CFBundleURLTypes', () {
    final updated = addGoogleSignInToInfoPlist(_plistWithUrlTypes);

    expect('<key>CFBundleURLTypes</key>'.allMatches(updated), hasLength(1));
    expect('<key>CFBundleURLSchemes</key>'.allMatches(updated), hasLength(2));
    expect(updated, contains('<string>bond</string>'));
    expect(addGoogleSignInToInfoPlist(updated), updated);
  });
}
