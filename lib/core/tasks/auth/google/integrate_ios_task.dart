import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';

const _urlType = '''
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>\$(GOOGLE_REVERSED_CLIENT_ID)</string>
			</array>
		</dict>
''';

/// Adds the Google Sign-In client IDs and the reversed client ID URL scheme
/// to an `Info.plist`. Running it again changes nothing, and an existing
/// `CFBundleURLTypes` array gets the scheme appended instead of a second key.
String addGoogleSignInToInfoPlist(String plist) {
  var result = plist;
  for (final (key, variable) in [
    ('GIDClientID', 'GOOGLE_CLIENT_ID'),
    ('GIDServerClientID', 'GOOGLE_SERVER_CLIENT_ID'),
  ]) {
    if (!result.contains('<key>$key</key>')) {
      result = _addToRootDict(
        result,
        '\t<key>$key</key>\n\t<string>\$($variable)</string>\n',
      );
    }
  }

  if (result.contains('GOOGLE_REVERSED_CLIENT_ID')) return result;
  final urlTypes = RegExp(r'<key>CFBundleURLTypes</key>\s*<array\s*(/?)>')
      .firstMatch(result);
  if (urlTypes == null) {
    return _addToRootDict(
      result,
      '\t<key>CFBundleURLTypes</key>\n\t<array>\n$_urlType\t</array>\n',
    );
  }
  final isEmptyArray = urlTypes[1] == '/';
  return result.replaceRange(
    isEmptyArray ? urlTypes.end - '<array/>'.length : urlTypes.end,
    urlTypes.end,
    isEmptyArray ? '<array>\n$_urlType\t</array>' : '\n${_urlType.trimRight()}',
  );
}

String _addToRootDict(String plist, String entry) {
  final closing = plist.lastIndexOf('</dict>');
  if (closing < 0) throw const FormatException('No top-level <dict>.');
  return plist.replaceRange(closing, closing, entry);
}

class IntegrateIosTask extends Task {
  @override
  String get actionDescription => 'Integrate Google Sign-In for iOS.';

  @override
  Future<void> execute() async {
    final infoPlist = File('ios/Runner/Info.plist');
    if (!infoPlist.existsSync()) {
      throw Exception('ios/Runner/Info.plist not found.');
    }
    final content = infoPlist.readAsStringSync();
    final updated = addGoogleSignInToInfoPlist(content);
    if (updated == content) {
      warn('Info.plist already contains the Google Sign-In configuration.');
      return;
    }
    infoPlist.writeAsStringSync(updated);
    warn(
      'Define GOOGLE_CLIENT_ID, GOOGLE_SERVER_CLIENT_ID and '
      'GOOGLE_REVERSED_CLIENT_ID as build settings (e.g. in '
      'ios/Flutter/Debug.xcconfig and Release.xcconfig) or replace the '
      r'$(...) placeholders in ios/Runner/Info.plist.',
    );
  }
}
