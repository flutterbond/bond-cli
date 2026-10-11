import 'dart:io';

import 'package:path/path.dart' as p;

import '../packages/bond_package_locator.dart';
import 'bundled_docs.dart';
import 'changelog.dart';

/// Upper bound for one tool answer, well below Claude Code's output limits.
const maxDocumentChars = 40000;

/// The documents of a package that can be read as MCP resources.
enum PackageDocument { readme, changelog, example }

/// Reads a document of [package]; `null` when the package has none.
String? readPackageDocument(BondPackage package, PackageDocument document) {
  switch (document) {
    case PackageDocument.readme:
      return _read(p.join(package.rootDir, 'README.md'));
    case PackageDocument.changelog:
      return _read(p.join(package.rootDir, 'CHANGELOG.md'));
    case PackageDocument.example:
      return _example(package);
  }
}

/// `package:` URIs of the libraries a user can import (everything in `lib/`
/// outside `lib/src/`, generated parts excluded).
List<String> publicLibraries(BondPackage package) {
  final lib = Directory(package.libDir);
  if (!lib.existsSync()) return const [];
  final libraries = <String>[];
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    final relative = p.relative(entity.path, from: lib.path);
    if (p.split(relative).first == 'src') continue;
    libraries.add(
      'package:${package.name}/${p.posix.joinAll(p.split(relative))}',
    );
  }
  return libraries..sort();
}

/// What the package is and how to use it: description, public libraries,
/// README, example and the latest [changelogSections] CHANGELOG sections.
String packageOverview(BondPackage package, {int changelogSections = 2}) {
  final out = StringBuffer()
    ..writeln('# ${package.name} ${package.version}')
    ..writeln()
    ..writeln(package.description)
    ..writeln()
    ..writeln('Resolved from: ${package.source.name} (${package.rootDir})')
    ..writeln()
    ..writeln('## Public libraries')
    ..writeln();
  for (final library in publicLibraries(package)) {
    out.writeln('- `import \'$library\';`');
  }

  final readme = readPackageDocument(package, PackageDocument.readme);
  out
    ..writeln()
    ..writeln('## README')
    ..writeln()
    ..writeln(readme ?? '_No README._');

  final example = readPackageDocument(package, PackageDocument.example);
  if (example != null) {
    out
      ..writeln()
      ..writeln('## Example')
      ..writeln()
      ..writeln(example);
  }

  final changelog = readPackageDocument(package, PackageDocument.changelog);
  if (changelog != null && changelogSections > 0) {
    out
      ..writeln()
      ..writeln('## Latest changes')
      ..writeln();
    for (final section in latestSections(changelog, changelogSections)) {
      out
        ..writeln(section.text)
        ..writeln();
    }
  }
  return truncate(out.toString());
}

/// Upgrade notes. Without [package]: the bundled migration guides of the
/// packages and of the template. With [package]: its section of the packages
/// guide plus its CHANGELOG sections after [from] up to [to] (default: the
/// resolved version).
String migrationNotes({BondPackage? package, String? from, String? to}) {
  if (package == null) {
    return truncate(
      '$packagesMigrationGuide\n\n---\n\n$templateMigrationGuide\n',
    );
  }
  final out = StringBuffer()
    ..writeln('# Migration notes for ${package.name}')
    ..writeln();
  final guideSection = _guideSection(package.name);
  if (guideSection != null) {
    out
      ..writeln(guideSection)
      ..writeln();
  }
  final changelog = readPackageDocument(package, PackageDocument.changelog);
  if (changelog != null) {
    final upTo = to ?? _versionOrNull(package.version);
    final sections = sectionsBetween(changelog, from: from, to: upTo);
    out
      ..writeln(
        '## CHANGELOG ${from == null ? 'up to' : 'after $from up to'} ${upTo ?? 'latest'}',
      )
      ..writeln();
    if (sections.isEmpty) out.writeln('_No CHANGELOG sections in that range._');
    for (final section in sections) {
      out
        ..writeln(section.text)
        ..writeln();
    }
  }
  return truncate(out.toString());
}

/// Cuts [text] to [maxChars] with a note, so one answer can't flood the context.
String truncate(String text, {int maxChars = maxDocumentChars}) {
  if (text.length <= maxChars) return text;
  return '${text.substring(0, maxChars)}\n\n'
      '[Truncated: ${text.length - maxChars} more characters. Ask for a '
      'narrower part, e.g. fewer CHANGELOG sections or one API symbol.]';
}

String? _read(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync().trim() : null;
}

/// `example/example.md`, or `example/README.md` plus the example's files
/// (for packages whose example is a whole app).
String? _example(BondPackage package) {
  final dir = Directory(p.join(package.rootDir, 'example'));
  if (!dir.existsSync()) return null;
  final markdown = _read(p.join(dir.path, 'example.md'));
  if (markdown != null) return markdown;

  final out = StringBuffer();
  final readme = _read(p.join(dir.path, 'README.md'));
  if (readme != null) out.writeln(readme);
  final files = [
    for (final entity in dir.listSync(recursive: true))
      if (entity is File && _isExampleSource(dir.path, entity.path))
        p.posix.joinAll(p.split(p.relative(entity.path, from: dir.path))),
  ]..sort();
  if (files.isNotEmpty) {
    out
      ..writeln()
      ..writeln(
        'Example app files (read them with the dart server\'s '
        'read_package_uris, `package-root:` URIs):',
      )
      ..writeln();
    for (final file in files.take(60)) {
      out.writeln('- example/$file');
    }
    if (files.length > 60) out.writeln('- ... ${files.length - 60} more');
  }
  return out.isEmpty ? null : out.toString().trim();
}

bool _isExampleSource(String root, String path) {
  final parts = p.split(p.relative(path, from: root));
  const skipped = {
    'build',
    '.dart_tool',
    'android',
    'ios',
    'macos',
    'web',
    'linux',
    'windows',
  };
  if (parts.any(skipped.contains)) return false;
  return path.endsWith('.dart') ||
      path.endsWith('.yaml') ||
      path.endsWith('.arb');
}

/// The `### ...` section of the packages migration guide that names [name].
String? _guideSection(String name) {
  final lines = packagesMigrationGuide.split('\n');
  final word = RegExp('\\b${RegExp.escape(name)}\\b');
  final start = lines.indexWhere(
    (l) => l.startsWith('### ') && word.hasMatch(l),
  );
  if (start < 0) return null;
  var end = start + 1;
  while (end < lines.length &&
      !lines[end].startsWith('### ') &&
      !lines[end].startsWith('## ')) {
    end++;
  }
  return lines.sublist(start, end).join('\n').trim();
}

String? _versionOrNull(String version) =>
    RegExp(r'^\d+\.\d+\.\d+').hasMatch(version) ? version : null;
