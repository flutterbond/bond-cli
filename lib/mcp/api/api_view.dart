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

  /// The offset after the first [shown] entries of this page, if any remain.
  int? nextOffset([int? shown]) {
    final next = offset + (shown ?? entries.length);
    return next < total ? next : null;
  }
}

/// Filters [all] by [symbol] and [library] and returns the page at [offset].
///
/// [all] lists a declaration once per public library that exports it; without
/// a [library] filter each declaration is kept once, from the first library
/// (the package's main library).
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
  final seen = <String>{};
  var entries = library == null || library.isEmpty
      ? [
          for (final e in all)
            if (seen.add('${e.file}#${e.name}')) e,
        ]
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

/// Markdown for one page of a package's API, at most [maxChars] long: the
/// page stops before the first entry that does not fit, and the "Next page"
/// offset continues from there.
String renderApi(
  BondPackage package,
  ApiPage page, {
  required ApiDetail detail,
  required bool members,
  int maxChars = maxDocumentChars,
}) {
  final title = '# ${package.name} ${package.version}: public API\n\n';
  if (page.total == 0) return '${title}No matching public declarations.\n';

  // Room for the title and the summary line.
  final budget = maxChars - title.length - 200;
  final body = StringBuffer();
  var shown = 0;
  String? currentLibrary;
  for (final entry in page.entries) {
    final block = StringBuffer();
    if (entry.library != currentLibrary) {
      block
        ..writeln()
        ..writeln('## ${entry.library}')
        ..writeln();
    }
    _writeEntry(block, entry, detail: detail, members: members);
    if (shown > 0 && body.length + block.length > budget) break;
    body.write(block);
    currentLibrary = entry.library;
    shown++;
  }

  final next = page.nextOffset(shown);
  final summary =
      'Showing ${page.offset + 1}-${page.offset + shown} of ${page.total} '
      'declarations (detail: ${detail.name}${members ? ', with members' : ''}).'
      '${next == null ? '' : ' Next page: offset=$next.'}';
  // A single entry larger than the budget is still cut.
  return truncate('$title$summary\n$body', maxChars: maxChars);
}

void _writeEntry(
  StringBuffer out,
  ApiEntry entry, {
  required ApiDetail detail,
  required bool members,
}) {
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
  if (!members) return;
  for (final member in entry.members) {
    final memberDeprecated = member.deprecated ? ' (deprecated)' : '';
    if (detail == ApiDetail.names) {
      out.writeln('  - ${member.kind} ${member.name}$memberDeprecated');
    } else {
      out.writeln('  - ${member.kind} `${member.signature}`$memberDeprecated');
      if (detail == ApiDetail.docs && member.doc != null) {
        out.writeln('    ${member.doc}');
      }
    }
  }
}
