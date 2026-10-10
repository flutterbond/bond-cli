import 'dart:io';

/// Replaces the [oldId] prefix of a dotted identifier such as a bundle ID,
/// keeping any suffix: `ps.app.bond.staging` -> `com.acme.staging`.
///
/// Returns [value] unchanged when it is not [oldId] or a child of it.
String renameIdPrefix(String value, String oldId, String newId) {
  if (value == oldId) return newId;
  if (value.startsWith('$oldId.')) return newId + value.substring(oldId.length);
  return value;
}

/// Keeps a suffix that [value] adds to [oldBase], e.g. a flavor name such as
/// `Bond Staging` -> `Acme Staging`. Anything else becomes [newBase].
String renameWithSuffix(String value, String oldBase, String newBase) =>
    value.startsWith(oldBase)
    ? newBase + value.substring(oldBase.length)
    : newBase;

/// Escapes text for an XML element body.
String xmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Rewrites [file] with [edit] and returns whether its content changed.
bool editFile(File file, String Function(String content) edit) {
  final content = file.readAsStringSync();
  final updated = edit(content);
  if (updated == content) return false;
  file.writeAsStringSync(updated);
  return true;
}

/// Lists files below [directory] whose path ends with one of [extensions].
List<File> listFiles(Directory directory, {required List<String> extensions}) {
  if (!directory.existsSync()) return const [];
  return directory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => extensions.any(file.path.endsWith))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}
