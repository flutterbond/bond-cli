/// Files of the flutter-bond template that never belong in a project: they
/// document the template repository itself.
const templateOnlyFiles = {'context7.json'};

/// Template files a project owns once it exists. `bond upgrade` never merges
/// their lines: it takes the new template's file only when the project did
/// not change it, and otherwise keeps the project's file and reports it.
///
/// - binaries (icons, splash images),
/// - lockfiles and generated code (tools regenerate them),
/// - Firebase identity (two Firebase projects must not be mixed hunk by hunk),
/// - Xcode project files (a conflicted `project.pbxproj` cannot be opened).
bool isOwnedFile(String path, {required bool binary}) {
  if (binary) return true;
  final name = path.split('/').last;
  return _ownedNames.contains(name) ||
      name.endsWith('.g.dart') ||
      (name.startsWith('firebase_options_') && name.endsWith('.dart')) ||
      (name.startsWith('firebase_app_id_file') && name.endsWith('.json')) ||
      (name.startsWith('app_localizations') && name.endsWith('.dart'));
}

const _ownedNames = {
  'pubspec.lock',
  'Podfile.lock',
  'Package.resolved',
  'GeneratedPluginRegistrant.swift',
  '.metadata',
  'google-services.json',
  'GoogleService-Info.plist',
  'firebase.json',
  'default_firebase_options.dart',
  'project.pbxproj',
};

/// Whether [bytes] look like a binary file (a NUL byte in the first 8 KiB).
bool looksBinary(List<int> bytes) {
  final end = bytes.length < 8192 ? bytes.length : 8192;
  for (var i = 0; i < end; i++) {
    if (bytes[i] == 0) return true;
  }
  return false;
}
