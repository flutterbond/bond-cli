import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:path/path.dart' as p;

import '../docs/package_docs.dart';
import '../packages/bond_package_locator.dart';

/// One public declaration (or member) of a package's API.
class ApiEntry {
  ApiEntry({
    required this.library,
    required this.kind,
    required this.name,
    required this.signature,
    required this.doc,
    required this.deprecated,
    required this.file,
    this.members = const [],
  });

  /// The public library (`package:x/y.dart`) that exposes it.
  final String library;
  final String kind;
  final String name;
  final String signature;

  /// First paragraph of the doc comment, if any.
  final String? doc;
  final bool deprecated;

  /// Path of the declaring file, relative to the package root.
  final String file;
  final List<ApiEntry> members;
}

/// Builds the public API of a package from its source: the declarations every
/// public library (`lib/` outside `lib/src/`) exports, following `export`
/// directives (with `show`/`hide`) and `part` files, without private names.
///
/// Only parses (no resolution), so it is fast and works on any package
/// version; signatures are the declarations' own source text.
class ApiOutlineExtractor {
  final _parsed = <String, (DateTime, CompilationUnit)>{};

  List<ApiEntry> extract(BondPackage package) {
    final entries = <ApiEntry>[];
    final seen = <String>{};
    final mainLibrary = 'package:${package.name}/${package.name}.dart';
    final libraries = publicLibraries(package)
      ..sort(
        (a, b) =>
            a == mainLibrary ? -1 : (b == mainLibrary ? 1 : a.compareTo(b)),
      );

    for (final library in libraries) {
      final relative = library.substring('package:${package.name}/'.length);
      _collect(
        package: package,
        library: library,
        path: p.join(package.libDir, p.joinAll(relative.split('/'))),
        filter: const _NameFilter(),
        visiting: {},
        seen: seen,
        into: entries,
      );
    }
    return entries;
  }

  void _collect({
    required BondPackage package,
    required String library,
    required String path,
    required _NameFilter filter,
    required Set<String> visiting,
    required Set<String> seen,
    required List<ApiEntry> into,
  }) {
    final normalized = p.normalize(path);
    if (!visiting.add(normalized)) return;
    final unit = _parse(normalized);
    if (unit == null) return;

    final units = [(normalized, unit)];
    for (final directive in unit.directives.whereType<PartDirective>()) {
      final partPath = _resolveUri(
        package,
        normalized,
        directive.uri.stringValue,
      );
      final part = partPath == null ? null : _parse(partPath);
      if (part != null) units.add((partPath!, part));
    }
    for (final (file, compilationUnit) in units) {
      final relativeFile = p.posix.joinAll(
        p.split(p.relative(file, from: package.rootDir)),
      );
      for (final declaration in compilationUnit.declarations) {
        for (final entry in _entries(declaration, library, relativeFile)) {
          if (_isPrivate(entry.name) || !filter.allows(entry.name)) continue;
          if (seen.add('${entry.file}#${entry.name}')) into.add(entry);
        }
      }
    }

    for (final directive in unit.directives.whereType<ExportDirective>()) {
      final target = _resolveUri(
        package,
        normalized,
        directive.uri.stringValue,
      );
      if (target == null) continue; // another package: not part of this API
      _collect(
        package: package,
        library: library,
        path: target,
        filter: filter.narrow(directive.combinators),
        visiting: visiting,
        seen: seen,
        into: into,
      );
    }
  }

  CompilationUnit? _parse(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    final modified = file.lastModifiedSync();
    final cached = _parsed[path];
    if (cached != null && cached.$1 == modified) return cached.$2;
    final unit = parseString(
      content: file.readAsStringSync(),
      path: path,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    ).unit;
    _parsed[path] = (modified, unit);
    return unit;
  }

  /// A relative or same-package `package:` URI as a file path; null otherwise.
  static String? _resolveUri(BondPackage package, String from, String? uri) {
    if (uri == null) return null;
    if (uri.startsWith('package:')) {
      final prefix = 'package:${package.name}/';
      if (!uri.startsWith(prefix)) return null;
      return p.join(
        package.libDir,
        p.joinAll(uri.substring(prefix.length).split('/')),
      );
    }
    if (uri.contains(':')) return null; // dart:, other schemes
    return p.normalize(p.join(p.dirname(from), p.joinAll(uri.split('/'))));
  }

  List<ApiEntry> _entries(
    CompilationUnitMember node,
    String library,
    String file,
  ) {
    ApiEntry entry(
      String kind,
      String name,
      String signature, {
      List<ApiEntry> members = const [],
    }) => ApiEntry(
      library: library,
      kind: kind,
      name: name,
      signature: signature,
      doc: _doc(node),
      deprecated: _deprecated(node),
      file: file,
      members: members,
    );

    switch (node) {
      case ClassDeclaration():
        final name = _className(node);
        return [
          entry(
            node.abstractKeyword != null ? 'abstract class' : 'class',
            name,
            _header(node),
            members: _members(_classMembers(node), name, library, file),
          ),
        ];
      case MixinDeclaration():
        return [
          entry(
            'mixin',
            node.name.lexeme,
            _header(node),
            members: _members(
              node.body.members,
              node.name.lexeme,
              library,
              file,
            ),
          ),
        ];
      case EnumDeclaration():
        final name = _enumName(node);
        return [
          entry(
            'enum',
            name,
            _header(node),
            members: [
              for (final constant in node.body.constants)
                if (!_isPrivate(constant.name.lexeme))
                  ApiEntry(
                    library: library,
                    kind: 'value',
                    name: constant.name.lexeme,
                    signature: '$name.${constant.name.lexeme}',
                    doc: _doc(constant),
                    deprecated: _deprecated(constant),
                    file: file,
                  ),
              ..._members(node.body.members, name, library, file),
            ],
          ),
        ];
      case ExtensionDeclaration():
        final name = node.name?.lexeme ?? '(unnamed extension)';
        return [
          entry(
            'extension',
            name,
            _header(node),
            members: _members(node.body.members, name, library, file),
          ),
        ];
      case ExtensionTypeDeclaration():
        final name = _extensionTypeName(node);
        return [
          entry(
            'extension type',
            name,
            _header(node),
            members: _members(node.body.members, name, library, file),
          ),
        ];
      case FunctionDeclaration():
        final kind = node.isGetter
            ? 'getter'
            : (node.isSetter ? 'setter' : 'function');
        return [entry(kind, node.name.lexeme, _header(node))];
      case TypeAlias():
        return [entry('typedef', node.name.lexeme, _text(node))];
      case TopLevelVariableDeclaration():
        return [
          for (final variable in node.variables.variables)
            entry(
              'variable',
              variable.name.lexeme,
              _variableSignature(node.variables, variable),
            ),
        ];
      default:
        return const [];
    }
  }

  List<ApiEntry> _members(
    NodeList<ClassMember> members,
    String owner,
    String library,
    String file,
  ) {
    final result = <ApiEntry>[];
    for (final member in members) {
      switch (member) {
        case ConstructorDeclaration():
          final named = member.name?.lexeme;
          final name = named == null ? owner : '$owner.$named';
          if (named != null && _isPrivate(named)) continue;
          result.add(
            _member(
              member,
              'constructor',
              name,
              _header(member, stopAtColonAndEquals: true),
              library,
              file,
            ),
          );
        case MethodDeclaration():
          final name = member.name.lexeme;
          if (_isPrivate(name)) continue;
          final kind = member.isGetter
              ? 'getter'
              : member.isSetter
              ? 'setter'
              : member.isOperator
              ? 'operator'
              : 'method';
          result.add(
            _member(
              member,
              member.isStatic ? 'static $kind' : kind,
              name,
              _header(member),
              library,
              file,
            ),
          );
        case FieldDeclaration():
          for (final variable in member.fields.variables) {
            final name = variable.name.lexeme;
            if (_isPrivate(name)) continue;
            result.add(
              _member(
                member,
                member.isStatic ? 'static field' : 'field',
                name,
                _variableSignature(member.fields, variable, prefixNode: member),
                library,
                file,
              ),
            );
          }
        default:
          break;
      }
    }
    return result;
  }

  ApiEntry _member(
    AnnotatedNode node,
    String kind,
    String name,
    String signature,
    String library,
    String file,
  ) => ApiEntry(
    library: library,
    kind: kind,
    name: name,
    signature: signature,
    doc: _doc(node),
    deprecated: _deprecated(node),
    file: file,
  );

  // --- analyzer AST adapter (analyzer 14.x names live only here) -------------

  static String _className(ClassDeclaration node) =>
      node.namePart.typeName.lexeme;

  static String _enumName(EnumDeclaration node) =>
      node.namePart.typeName.lexeme;

  static String _extensionTypeName(ExtensionTypeDeclaration node) =>
      node.namePart.typeName.lexeme;

  static NodeList<ClassMember> _classMembers(ClassDeclaration node) =>
      node.body.members;

  // ---------------------------------------------------------------------------

  static bool _isPrivate(String name) => name.startsWith('_');

  /// The declaration's source from its first keyword up to its body
  /// (`{`, `=>`, `;` — and `:`/`=` for constructors), on one line.
  static String _header(
    AnnotatedNode node, {
    bool stopAtColonAndEquals = false,
  }) {
    final buffer = StringBuffer();
    var token = node.firstTokenAfterCommentAndMetadata;
    Token? previous;
    var depth = 0;
    while (true) {
      final lexeme = token.lexeme;
      if (depth == 0 &&
          (lexeme == '{' ||
              lexeme == '=>' ||
              lexeme == ';' ||
              (stopAtColonAndEquals && (lexeme == ':' || lexeme == '=')))) {
        break;
      }
      if (lexeme == '(' || lexeme == '[') depth++;
      if (lexeme == ')' || lexeme == ']') depth--;
      if (previous != null && token.offset > previous.end) buffer.write(' ');
      buffer.write(lexeme);
      previous = token;
      if (token == node.endToken || token.next == null || token.next!.isEof) {
        break;
      }
      token = token.next!;
    }
    return buffer.toString();
  }

  /// The whole declaration (for typedefs), on one line.
  static String _text(AnnotatedNode node) {
    final buffer = StringBuffer();
    Token? previous;
    for (
      Token? token = node.firstTokenAfterCommentAndMetadata;
      token != null;
      token = token.next
    ) {
      if (previous != null && token.offset > previous.end) buffer.write(' ');
      buffer.write(token.lexeme);
      previous = token;
      if (token == node.endToken) break;
    }
    return buffer.toString();
  }

  /// `final String name` for one variable of a declaration list.
  static String _variableSignature(
    VariableDeclarationList list,
    VariableDeclaration variable, {
    AnnotatedNode? prefixNode,
  }) {
    final buffer = StringBuffer();
    Token? previous;
    final first = list.variables.first.name;
    for (
      Token? token = (prefixNode ?? list).firstTokenAfterCommentAndMetadata;
      token != null && token != first;
      token = token.next
    ) {
      if (previous != null && token.offset > previous.end) buffer.write(' ');
      buffer.write(token.lexeme);
      previous = token;
    }
    return '${buffer.toString().trim()} ${variable.name.lexeme}'.trim();
  }

  static String? _doc(AnnotatedNode node) {
    final comment = node.documentationComment;
    if (comment == null) return null;
    final lines = <String>[];
    for (final token in comment.tokens) {
      var text = token.lexeme.trim();
      if (text.startsWith('///')) {
        text = text.substring(3);
        if (text.startsWith(' ')) text = text.substring(1);
        lines.add(text);
      } else {
        for (final line
            in text
                .replaceFirst('/**', '')
                .replaceFirst(RegExp(r'\*/$'), '')
                .split('\n')) {
          lines.add(line.trim().replaceFirst(RegExp(r'^\*\s?'), ''));
        }
      }
    }
    final paragraph = lines
        .skipWhile((l) => l.trim().isEmpty)
        .takeWhile((l) => l.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (paragraph.isEmpty) return null;
    return paragraph.length <= 300
        ? paragraph
        : '${paragraph.substring(0, 297)}...';
  }

  static bool _deprecated(AnnotatedNode node) => node.metadata.any(
    (a) => a.name.name == 'Deprecated' || a.name.name == 'deprecated',
  );
}

/// Names allowed through a chain of `export ... show/hide` combinators.
class _NameFilter {
  const _NameFilter([this.show, this.hide = const {}]);

  final Set<String>? show;
  final Set<String> hide;

  bool allows(String name) =>
      (show == null || show!.contains(name)) && !hide.contains(name);

  _NameFilter narrow(NodeList<Combinator> combinators) {
    var show = this.show;
    final hide = {...this.hide};
    for (final combinator in combinators) {
      switch (combinator) {
        case ShowCombinator():
          final names = {for (final id in combinator.shownNames) id.name};
          show = show == null ? names : show.intersection(names);
        case HideCombinator():
          hide.addAll(combinator.hiddenNames.map((id) => id.name));
      }
    }
    return _NameFilter(show, hide);
  }
}
