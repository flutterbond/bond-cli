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
/// - Xcode project files (a conflicted `project.pbxproj` cannot be opened),
/// - the root README and CONTRIBUTING, which every project rewrites.
bool isOwnedFile(String path, {required bool binary}) =>
    ownedKind(path, binary: binary) != null;

/// What kind of owned file [path] is ("lockfile", ...), or null when it is
/// merged line by line.
String? ownedKind(String path, {required bool binary}) {
  if (binary) return 'binary file';
  if (path == 'README.md' || path == 'CONTRIBUTING.md') return 'project docs';
  final name = path.split('/').last;
  if (name.endsWith('.g.dart') ||
      name.startsWith('app_localizations') && name.endsWith('.dart') ||
      name == 'GeneratedPluginRegistrant.swift' ||
      name == '.metadata') {
    return 'generated file';
  }
  if (name == 'pubspec.lock' ||
      name == 'Podfile.lock' ||
      name == 'Package.resolved') {
    return 'lockfile';
  }
  if (name == 'google-services.json' ||
      name == 'GoogleService-Info.plist' ||
      name == 'firebase.json' ||
      name == 'default_firebase_options.dart' ||
      name.startsWith('firebase_options_') && name.endsWith('.dart') ||
      name.startsWith('firebase_app_id_file') && name.endsWith('.json')) {
    return 'Firebase file';
  }
  if (name == 'project.pbxproj') return 'Xcode project file';
  return null;
}

/// Whether [bytes] look like a binary file (a NUL byte in the first 8 KiB).
bool looksBinary(List<int> bytes) {
  final end = bytes.length < 8192 ? bytes.length : 8192;
  for (var i = 0; i < end; i++) {
    if (bytes[i] == 0) return true;
  }
  return false;
}
