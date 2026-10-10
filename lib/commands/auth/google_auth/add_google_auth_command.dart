import 'package:args/command_runner.dart';
import 'package:bond_cli/core/tasks/auth/add_google_auth_task.dart';
import 'package:bond_cli/core/tasks/auth/google/check_firebase_integration_task.dart';
import 'package:bond_cli/core/utils.dart';

class AddGoogleAuthCommand extends Command<void> with InputResolver {
  @override
  String get name => 'google_auth';

  @override
  String get description =>
      'Automates the process of adding Google Sign-In to a Flutter app.';

  AddGoogleAuthCommand();

  @override
  Future<void> run() async {
    requireFlutterProject();
    final firebaseIntegrated = await CheckFirebaseIntegrationTask().run();
    if (!firebaseIntegrated) {
      throw Exception(
        'Firebase is not integrated. Add a google-services.json (one of '
        '${CheckFirebaseIntegrationTask.androidPaths.join(', ')}) and a '
        'GoogleService-Info.plist (one of '
        '${CheckFirebaseIntegrationTask.iosPaths.join(', ')}) first.',
      );
    }
    await AddGoogleAuthTask().run();
  }
}
