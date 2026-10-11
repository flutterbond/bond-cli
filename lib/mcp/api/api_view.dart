import '../docs/package_docs.dart';
import '../packages/bond_package_locator.dart';
import 'api_outline.dart';

/// How much of each API entry to show.
enum ApiDetail { names, signatures, docs }

/// One page of a filtered API outline.
class ApiPage {
  const ApiPage(this.entries, {required this.total, required this.offset});

  final List<ApiEntry> entries;
  final int total;
  final int offset;

  int? get nextOffset =>
      offset + entries.length < total ? offset + entries.length : null;
}

/// Filters [all] by [symbol] and [library] and returns the page at [offset].
///
/// [symbol]: exact declaration names win; otherwise a case-insensitive match
/// on declaration names, then on member names (keeping only matching members).
ApiPage selectApi(
  List<ApiEntry> all, {
  String? symbol,
  String? library,
  int offset = 0,
  int limit = 50,
}) {
  var entries = library == null || library.isEmpty
      ? all
      : [
          for (final e in all)
            if (e.library.endsWith(library)) e,
        ];

  if (symbol != null && symbol.isNotEmpty) {
    final exact = [
      for (final e in entries)
        if (e.name == symbol) e,
    ];
    if (exact.isNotEmpty) {
      entries = exact;
    } else {
      final query = symbol.toLowerCase();
      final byName = [
        for (final e in entries)
          if (e.name.toLowerCase().contains(query)) e,
      ];
      entries = byName.isNotEmpty
          ? byName
          : [
              for (final e in entries)
                if (e.members.any((m) => m.name.toLowerCase().contains(query)))
                  ApiEntry(
                    library: e.library,
                    kind: e.kind,
                    name: e.name,
                    signature: e.signature,
                    doc: e.doc,
                    deprecated: e.deprecated,
                    file: e.file,
                    members: [
                      for (final m in e.members)
                        if (m.name.toLowerCase().contains(query)) m,
                    ],
                  ),
            ];
    }
  }
  final start = offset.clamp(0, entries.length);
  final end = (start + limit).clamp(start, entries.length);
  return ApiPage(
    entries.sublist(start, end),
    total: entries.length,
    offset: start,
  );
}

/// Markdown for one page of a package's API.
String renderApi(
  BondPackage package,
  ApiPage page, {
  required ApiDetail detail,
  required bool members,
}) {
  final out = StringBuffer()
    ..writeln('# ${package.name} ${package.version}: public API')
    ..writeln();
  if (page.total == 0) {
    out.writeln('No matching public declarations.');
    return out.toString();
  }
  out.writeln(
    'Showing ${page.offset + 1}-${page.offset + page.entries.length} of '
    '${page.total} declarations (detail: ${detail.name}'
    '${members ? ', with members' : ''}).'
    '${page.nextOffset == null ? '' : ' Next page: offset=${page.nextOffset}.'}',
  );

  String? currentLibrary;
  for (final entry in page.entries) {
    if (entry.library != currentLibrary) {
      currentLibrary = entry.library;
      out
        ..writeln()
        ..writeln('## ${entry.library}')
        ..writeln();
    }
    final deprecated = entry.deprecated ? ' (deprecated)' : '';
    switch (detail) {
      case ApiDetail.names:
        out.writeln('- ${entry.kind} ${entry.name}$deprecated');
      case ApiDetail.signatures:
      case ApiDetail.docs:
        out.writeln('- `${entry.signature}`$deprecated  _(${entry.file})_');
        if (detail == ApiDetail.docs && entry.doc != null) {
          out.writeln('  ${entry.doc}');
        }
    }
    if (members) {
      for (final member in entry.members) {
        final memberDeprecated = member.deprecated ? ' (deprecated)' : '';
        if (detail == ApiDetail.names) {
          out.writeln('  - ${member.kind} ${member.name}$memberDeprecated');
        } else {
          out.writeln(
            '  - ${member.kind} `${member.signature}`$memberDeprecated',
          );
          if (detail == ApiDetail.docs && member.doc != null) {
            out.writeln('    ${member.doc}');
          }
        }
      }
    }
  }
  return truncate(out.toString());
}
