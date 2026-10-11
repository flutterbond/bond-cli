import 'dart:io';

import 'package:path/path.dart' as p;

import 'text_edits.dart';

/// Character ranges of the `XCBuildConfiguration` objects of a pbxproj.
Iterable<(int, int)> _buildConfigurationRanges(String pbxproj) sync* {
  const begin = '/* Begin XCBuildConfiguration section */';
  const end = '/* End XCBuildConfiguration section */';
  final sectionStart = pbxproj.indexOf(begin);
  final sectionEnd = pbxproj.indexOf(end);
  if (sectionStart < 0 || sectionEnd < sectionStart) return;

  var depth = 0;
  var objectStart = 0;
  var inString = false;
  for (var i = sectionStart + begin.length; i < sectionEnd; i++) {
    final char = pbxproj[i];
    if (inString) {
      if (char == r'\') {
        i++;
      } else if (char == '"') {
        inString = false;
      }
    } else if (char == '"') {
      inString = true;
    } else if (char == '{') {
      if (depth++ == 0) objectStart = i;
    } else if (char == '}') {
      if (--depth == 0) yield (objectStart, i + 1);
    }
  }
}

final _configurationName = RegExp(
  r'^\s*name = ("(?:[^"\\]|\\.)*"|[^;\n]*);',
  multiLine: true,
);

RegExp _buildSetting(String key) => RegExp(
  '^(\\s*${RegExp.escape(key)} = )("(?:[^"\\\\]|\\\\.)*"|[^;\\n]*);',
  multiLine: true,
);

String _unquote(String value) => value.startsWith('"')
    ? value
          .substring(1, value.length - 1)
          .replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!)
    : value;

String _quote(String value) => RegExp(r'^[A-Za-z0-9_$/:.\-]+$').hasMatch(value)
    ? value
    : '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// Reads [key] from every build configuration as `(configuration, value)`.
List<(String, String)> readBuildSettings(String pbxproj, String key) => [
  for (final (start, end) in _buildConfigurationRanges(pbxproj))
    for (final match in _buildSetting(
      key,
    ).allMatches(pbxproj.substring(start, end)))
      (
        _unquote(
          _configurationName
                  .allMatches(pbxproj.substring(start, end))
                  .lastOrNull
                  ?.group(1) ??
              '',
        ),
        _unquote(match[2]!),
      ),
];

/// Rewrites [key] in every build configuration with [edit], which receives
/// the configuration name and the current value.
String editBuildSettings(
  String pbxproj,
  String key,
  String Function(String configuration, String value) edit,
) {
  final buffer = StringBuffer();
  var last = 0;
  for (final (start, end) in _buildConfigurationRanges(pbxproj)) {
    final object = pbxproj.substring(start, end);
    final name = _unquote(
      _configurationName.allMatches(object).lastOrNull?.group(1) ?? '',
    );
    buffer
      ..write(pbxproj.substring(last, start))
      ..write(
        object.replaceAllMapped(
          _buildSetting(key),
          (m) => '${m[1]}${_quote(edit(name, _unquote(m[2]!)))};',
        ),
      );
    last = end;
  }
  buffer.write(pbxproj.substring(last));
  return buffer.toString();
}

bool _isVariable(String value) =>
    value.contains(r'$(') || value.contains(r'${');

/// The bundle ID the others derive from, e.g. `ps.app.bond` for
/// `ps.app.bond`, `ps.app.bond.staging` and `ps.app.bond.RunnerTests`.
String? detectBaseBundleId(String pbxproj) {
  final ids = readBuildSettings(
    pbxproj,
    'PRODUCT_BUNDLE_IDENTIFIER',
  ).map((setting) => setting.$2).where((id) => !_isVariable(id)).toList();
  if (ids.isEmpty) return null;
  return ids.reduce((a, b) => b.length < a.length ? b : a);
}

/// Replaces the base bundle ID in every build configuration while keeping
/// suffixes such as `.staging` or `.RunnerTests`.
String renameBundleIds(String pbxproj, String newBaseId) {
  final oldBaseId = detectBaseBundleId(pbxproj);
  if (oldBaseId == null) {
    throw const FormatException('No PRODUCT_BUNDLE_IDENTIFIER found.');
  }
  return editBuildSettings(
    pbxproj,
    'PRODUCT_BUNDLE_IDENTIFIER',
    (_, id) => renameIdPrefix(id, oldBaseId, newBaseId),
  );
}

RegExp _plistString(String key) =>
    RegExp('(<key>${RegExp.escape(key)}</key>\\s*<string>)([^<]*)(</string>)');

/// Reads the raw `<string>` value that follows `<key>[key]</key>`.
String? readPlistString(String plist, String key) =>
    _plistString(key).firstMatch(plist)?.group(2);

/// Sets the `<string>` value of [key], adding it to the top-level `<dict>`
/// when missing.
String setPlistString(String plist, String key, String value) {
  final escaped = xmlEscape(value);
  final pattern = _plistString(key);
  if (pattern.hasMatch(plist)) {
    return plist.replaceFirstMapped(pattern, (m) => '${m[1]}$escaped${m[3]}');
  }
  final closing = plist.lastIndexOf('</dict>');
  if (closing < 0) throw const FormatException('No top-level <dict>.');
  return plist.replaceRange(
    closing,
    closing,
    '\t<key>$key</key>\n\t<string>$escaped</string>\n',
  );
}

/// The `ios/` part of a Flutter project.
class IosProject {
  final Directory root;

  /// [root] is the Flutter project root (the folder holding `ios/`).
  IosProject(this.root);

  Directory get iosDirectory => Directory(p.join(root.path, 'ios'));

  File get pbxproj =>
      File(p.join(iosDirectory.path, 'Runner.xcodeproj', 'project.pbxproj'));

  File get infoPlist => File(p.join(iosDirectory.path, 'Runner', 'Info.plist'));

  String? get bundleId => detectBaseBundleId(pbxproj.readAsStringSync());

  /// The home-screen name (`CFBundleDisplayName`), or null when it is missing
  /// or set from a build setting.
  String? get displayName {
    final value = readPlistString(
      infoPlist.readAsStringSync(),
      'CFBundleDisplayName',
    );
    if (value == null || _isVariable(value)) return null;
    return xmlUnescape(value);
  }

  /// Firebase configs such as `ios/Production/GoogleService-Info.plist`.
  List<File> get _googleServiceInfoPlists =>
      listFiles(iosDirectory, extensions: ['GoogleService-Info.plist'])
          .where(
            (file) => !p
                .split(p.relative(file.path, from: iosDirectory.path))
                .any(
                  (part) => const {'Pods', '.symlinks', 'build'}.contains(part),
                ),
          )
          .toList();

  /// Renames the bundle IDs of all build configurations (keeping `.staging`
  /// and other suffixes) and the `BUNDLE_ID` of each
  /// `GoogleService-Info.plist`.
  ///
  /// Returns warnings for parts that could not be updated.
  List<String> setBundleId(String newId) {
    final warnings = <String>[];
    final content = pbxproj.readAsStringSync();
    final oldId = detectBaseBundleId(content);
    if (oldId == null) {
      throw FormatException('No PRODUCT_BUNDLE_IDENTIFIER in ${pbxproj.path}.');
    }
    if (oldId == newId) return warnings;
    pbxproj.writeAsStringSync(renameBundleIds(content, newId));

    for (final file in _googleServiceInfoPlists) {
      final plist = file.readAsStringSync();
      final bundleId = readPlistString(plist, 'BUNDLE_ID');
      if (bundleId == null) continue;
      final renamed = renameIdPrefix(bundleId, oldId, newId);
      if (renamed == bundleId) {
        warnings.add(
          '${p.relative(file.path, from: root.path)} has BUNDLE_ID $bundleId; '
          'download it again from the Firebase console.',
        );
        continue;
      }
      file.writeAsStringSync(setPlistString(plist, 'BUNDLE_ID', renamed));
    }
    return warnings;
  }

  /// Sets `CFBundleDisplayName` (home screen) and `CFBundleName` in
  /// `Info.plist`. A value that references a build setting, e.g.
  /// `$(APP_DISPLAY_NAME)`, is renamed in each build configuration instead,
  /// keeping flavor suffixes; `$(PRODUCT_NAME)` is left alone.
  List<String> setAppName({
    required String displayName,
    required String bundleName,
  }) {
    final warnings = <String>[];
    var plist = infoPlist.readAsStringSync();
    var project = pbxproj.readAsStringSync();
    for (final (key, value) in [
      ('CFBundleDisplayName', displayName),
      ('CFBundleName', bundleName),
    ]) {
      final current = readPlistString(plist, key);
      final variable = current == null
          ? null
          : RegExp(r'^\$[({](\w+)[)}]$').firstMatch(current.trim())?.group(1);
      if (variable == null) {
        plist = setPlistString(plist, key, value);
      } else if (variable != 'PRODUCT_NAME' && variable != 'TARGET_NAME') {
        final values = readBuildSettings(project, variable);
        if (values.isEmpty) {
          warnings.add('$key uses \$($variable), which no build setting sets.');
          continue;
        }
        final base = values
            .map((setting) => setting.$2)
            .reduce((a, b) => b.length < a.length ? b : a);
        project = editBuildSettings(
          project,
          variable,
          (_, old) => renameWithSuffix(old, base, value),
        );
      }
    }
    infoPlist.writeAsStringSync(plist);
    pbxproj.writeAsStringSync(project);
    return warnings;
  }
}
