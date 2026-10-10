import 'dart:io';

import 'package:bond_cli/core/tasks/core/task.dart';

class CheckFirebaseIntegrationTask extends Task<bool> {
  /// Per-flavor Firebase configs of the template, plus the single-flavor
  /// locations FlutterFire uses by default.
  static const androidPaths = [
    'android/app/src/production/google-services.json',
    'android/app/src/staging/google-services.json',
    'android/app/google-services.json',
  ];

  static const iosPaths = [
    'ios/Production/GoogleService-Info.plist',
    'ios/Staging/GoogleService-Info.plist',
    'ios/Runner/GoogleService-Info.plist',
  ];

  @override
  String get actionDescription => 'Check Firebase integration.';

  @override
  Future<bool> execute() async {
    bool exists(String path) {
      final file = File(path);
      return file.existsSync() && file.lengthSync() > 0;
    }

    return androidPaths.any(exists) && iosPaths.any(exists);
  }
}
