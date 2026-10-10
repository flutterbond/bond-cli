import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';

class CreateConfigurationFileTask extends Task {
  @override
  String get actionDescription => 'Create google_auth.dart configuration file.';

  @override
  Future<void> execute() async {
    final configPath = 'lib/config/google_auth.dart';
    final configFile = File(configPath);
    final content = '''
/// Google Auth Configurations
///
/// ------------------------------------------------------------------------
/// Google Sign-In Configuration
/// ------------------------------------------------------------------------
///
/// In order to access Google services, the application needs to be authenticated
/// using OAuth 2.0. This involves providing a Client ID, Scopes, and optionally a
/// Server Client ID if backend authentication is required.
///
/// For detailed instructions on setting up Google Sign-In, refer to the official
/// documentation at:
///
/// https://developers.google.com/identity
///
/// Ensure that these variables are set in your environment configuration files
/// (env.json, env.staging.json) as shown below:
///
/// ------------------------------------------------------------------------

const googleAuthConfigs = {
  /// ------------------------------------------------------------------------
  /// GOOGLE_CLIENT_ID
  /// ------------------------------------------------------------------------
  ///
  /// The OAuth client ID for your app. This is required.
  ///
  /// To obtain this:
  /// 1. Go to the Google Developer Console.
  /// 2. Create a new project or select an existing one.
  /// 3. Navigate to "APIs & Services" > "Credentials".
  /// 4. Create an OAuth 2.0 Client ID for Web Application.
  ///
  'GOOGLE_CLIENT_ID': String.fromEnvironment('GOOGLE_CLIENT_ID'),

  /// ------------------------------------------------------------------------
  /// GOOGLE_SCOPES
  /// ------------------------------------------------------------------------
  ///
  /// The scopes required by your app. Example: "email, profile".
  ///
  /// Define the scopes your app needs access to, which might include:
  /// - email
  /// - profile
  ///
  'GOOGLE_SCOPES': String.fromEnvironment('GOOGLE_SCOPES'),

  /// ------------------------------------------------------------------------
  /// GOOGLE_SERVER_CLIENT_ID
  /// ------------------------------------------------------------------------
  ///
  /// The OAuth client ID for your backend server. This is optional.
  ///
  /// To obtain this:
  /// 1. Go to the Google Developer Console.
  /// 2. Create a new project or select an existing one.
  /// 3. Navigate to "APIs & Services" > "Credentials".
  /// 4. Create an OAuth 2.0 Client ID for Web Application.
  ///
  'GOOGLE_SERVER_CLIENT_ID': String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),

  /// ------------------------------------------------------------------------
  /// GOOGLE_REVERSED_CLIENT_ID
  /// ------------------------------------------------------------------------
  ///
  /// The reversed client ID for your app, used for URL schemes.
  ///
  /// This value is typically found in the GoogleService-Info.plist file.
  ///
  'GOOGLE_REVERSED_CLIENT_ID': String.fromEnvironment('GOOGLE_REVERSED_CLIENT_ID'),
};
''';

    if (!configFile.existsSync()) {
      configFile.createSync(recursive: true);
      configFile.writeAsStringSync(content);
    } else {
      warn('lib/config/google_auth.dart already exists.');
    }
  }
}
