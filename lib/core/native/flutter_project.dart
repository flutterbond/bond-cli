import 'dart:io';

import 'package:path/path.dart' as p;

import 'text_edits.dart';

final _pubspecName = RegExp(r'^(name:[ \t]*)(\S+)[ \t]*$', multiLine: true);

String? readPubspecName(String pubspec) =>
    _pubspecName.firstMatch(pubspec)?.group(2);

String setPubspecName(String pubspec, String name) {
  if (!_pubspecName.hasMatch(pubspec)) {
    throw const FormatException('No `name:` found in pubspec.yaml.');
  }
  return pubspec.replaceFirstMapped(_pubspecName, (m) => '${m[1]}$name');
}

/// Rewrites `package:<oldName>/` URIs in imports, exports and parts.
String renamePackageUris(String source, String oldName, String newName) =>
    source.replaceAll(
      RegExp('(?<=[\'"])package:${RegExp.escape(oldName)}/'),
      'package:$newName/',
    );

/// Renames string literals that hold [oldId] or a child of it, e.g.
/// `'ps.app.bond.staging'`.
///
/// A literal belongs to iOS when the text before it on its line (or on the
/// previous line, when the literal starts its line) mentions "ios", as in
/// `iosBundleId: '...'` or `IOS_BUNDLE_ID="..."`; only literals of the
/// requested platform are renamed.
String renameAppIdLiterals(
  String source, {
  required String oldId,
  required String newId,
  required bool ios,
}) => source.replaceAllMapped(
  RegExp('([\'"])(${RegExp.escape(oldId)}(?:\\.[\\w.-]+)?)\\1'),
  (m) {
    int lineStartBefore(int index) =>
        index <= 0 ? 0 : source.lastIndexOf('\n', index - 1) + 1;
    var lineStart = lineStartBefore(m.start);
    if (source.substring(lineStart, m.start).trim().isEmpty) {
      lineStart = lineStartBefore(lineStart - 1);
    }
    final context = source.substring(lineStart, m.start).toLowerCase();
    if (context.contains('ios') != ios) return m[0]!;
    return '${m[1]}${renameIdPrefix(m[2]!, oldId, newId)}${m[1]}';
  },
);

/// The Dart side of a Flutter project.
class FlutterProject {
  final Directory root;

  FlutterProject(this.root);

  static const _sourceDirectories = [
    'lib',
    'test',
    'integration_test',
    'test_driver',
  ];

  File get pubspec => File(p.join(root.path, 'pubspec.yaml'));

  String? get name => readPubspecName(pubspec.readAsStringSync());

  /// Whether `pubspec.yaml` lists [package] as a dependency of any kind.
  bool dependsOn(String package) => RegExp(
    '^[ \\t]+${RegExp.escape(package)}:',
    multiLine: true,
  ).hasMatch(pubspec.readAsStringSync());

  List<File> get _dartFiles => [
    for (final directory in _sourceDirectories)
      ...listFiles(
        Directory(p.join(root.path, directory)),
        extensions: ['.dart'],
      ),
  ];

  /// Renames the package in `pubspec.yaml` and rewrites `package:` URIs in
  /// `lib/`, `test/`, `integration_test/` and `test_driver/`.
  ///
  /// Returns the number of Dart files that changed.
  int rename(String newName) {
    final oldName = name;
    if (oldName == null) {
      throw FormatException('No `name:` in ${pubspec.path}.');
    }
    if (oldName == newName) return 0;
    editFile(pubspec, (content) => setPubspecName(content, newName));
    return _dartFiles
        .where(
          (file) => editFile(
            file,
            (content) => renamePackageUris(content, oldName, newName),
          ),
        )
        .length;
  }

  /// Renames the [ios] or Android app ID literals in Dart sources (e.g.
  /// `iosBundleId` in `firebase_options_*.dart`) and in
  /// `firebase_config.bash`.
  ///
  /// Returns the number of files that changed.
  int renameAppId({
    required String oldId,
    required String newId,
    required bool ios,
  }) {
    if (oldId == newId) return 0;
    final files = [
      ..._dartFiles,
      File(p.join(root.path, 'firebase_config.bash')),
    ].where((file) => file.existsSync());
    return files
        .where(
          (file) => editFile(
            file,
            (content) => renameAppIdLiterals(
              content,
              oldId: oldId,
              newId: newId,
              ios: ios,
            ),
          ),
        )
        .length;
  }
}
