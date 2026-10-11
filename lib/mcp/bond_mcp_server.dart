import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:path/path.dart' as p;

import '../core/generators/generators.dart';
import '../version.dart';
import 'api/api_outline.dart';
import 'api/api_view.dart';
import 'docs/bundled_docs.dart';
import 'docs/package_docs.dart';
import 'packages/bond_package_locator.dart';

/// An error the client should see as a plain message (no stack trace).
class ToolError implements Exception {
  ToolError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// MCP server that teaches an agent the Flutter Bond packages a project uses:
/// what each package does, its documentation and its upgrade notes, always
/// for the exact versions the project resolves.
final class BondMcpServer extends MCPServer
    with LoggingSupport, ToolsSupport, ResourcesSupport, RootsTrackingSupport {
  BondMcpServer(
    super.channel, {
    this.projectFallback,
    BondPackageLocator? locator,
    super.protocolLogSink,
  }) : locator = locator ?? BondPackageLocator(),
       super.fromStreamChannel(
         implementation: Implementation(
           name: 'bond',
           title: 'Flutter Bond',
           version: bondCliVersion,
         ),
         instructions: serverInstructions,
       ) {
    registerTool(packagesTool, _packages);
    registerTool(packageOverviewTool, _packageOverview);
    registerTool(migrationTool, _migration);
    registerTool(apiTool, _apiOutline);
    registerTool(createModelTool, _createModel);
    registerTool(createWidgetTool, _createWidget);
    registerTool(createServiceProviderTool, _createServiceProvider);
    registerTool(createProjectTool, _createProject);
    _addResources();
  }

  /// Used when the client reports no roots (from `bond mcp --project`).
  final Directory? projectFallback;
  final BondPackageLocator locator;
  final _api = ApiOutlineExtractor();

  static const serverInstructions =
      'Flutter Bond is a Flutter framework: the bond_* packages (bond_core: '
      'service providers and get_it `sl`; bond_network: BondFire HTTP requests; '
      'bond_cache; bond_form with Riverpod/GetX/Bloc adapters; '
      'bond_notifications; bond_app_analytics) and the flutter-bond app '
      'template. This server answers from the exact package versions the '
      'current project resolves (.dart_tool/package_config.json). Use '
      '`packages` to see them, `package_overview` to learn what a package does '
      'and how to use it, `api` for its real public API (classes, constructors, '
      'methods, fields with their signatures and docs, read from the source; '
      'filter with `symbol`), and `migration` for upgrade notes between versions. '
      'To scaffold code the Bond way use create_model, create_widget, '
      'create_service_provider (they write into the project and never overwrite) '
      'and create_project (clones the flutter-bond template). '
      'For raw source files or text search inside a package, use the `dart` '
      'MCP server\'s read_package_uris / rip_grep_packages. Every tool accepts '
      'an optional `root` (project directory) when the client has several '
      'roots; run `flutter pub get` first if a project has no package config.';

  static final _rootProperty = Schema.string(
    description:
        'Project directory (absolute path or file: URI). Defaults to the '
        'client root that has a package config.',
  );

  static final _packageProperty = Schema.string(
    description: 'Package name, e.g. bond_core or bond_form_riverpod.',
  );

  static final packagesTool = Tool(
    name: 'packages',
    title: 'Bond packages of the project',
    description:
        'Lists the bond_* packages the project depends on, with the resolved '
        'version, description, source (hosted/git/path) and root directory.',
    annotations: ToolAnnotations(readOnlyHint: true, openWorldHint: false),
    inputSchema: Schema.object(
      properties: {'root': _rootProperty},
      additionalProperties: false,
    ),
  );

  static final packageOverviewTool = Tool(
    name: 'package_overview',
    title: 'What a Bond package does and how to use it',
    description:
        'Returns a bond_* package\'s description, public libraries to import, '
        'README, example and its latest CHANGELOG sections, for the version '
        'the project resolves.',
    annotations: ToolAnnotations(readOnlyHint: true, openWorldHint: false),
    inputSchema: Schema.object(
      properties: {
        'package': _packageProperty,
        'changelogSections': Schema.int(
          description:
              'How many recent CHANGELOG sections to include '
              '(default 2, 0 for none).',
          minimum: 0,
          maximum: 20,
        ),
        'root': _rootProperty,
      },
      required: ['package'],
      additionalProperties: false,
    ),
  );

  static final migrationTool = Tool(
    name: 'migration',
    title: 'Bond upgrade notes',
    description:
        'Upgrade notes. Without `package`: the migration guides of the bond_* '
        'packages and of the flutter-bond template. With `package`: its '
        'section of the guide and its CHANGELOG between `from` (exclusive) '
        'and `to` (default: the resolved version).',
    annotations: ToolAnnotations(readOnlyHint: true, openWorldHint: false),
    inputSchema: Schema.object(
      properties: {
        'package': _packageProperty,
        'from': Schema.string(
          description: 'Version upgraded from, e.g. 0.0.22+19.',
        ),
        'to': Schema.string(description: 'Version upgraded to, e.g. 0.1.0.'),
        'root': _rootProperty,
      },
      additionalProperties: false,
    ),
  );

  static final apiTool = Tool(
    name: 'api',
    title: 'Public API of a Bond package',
    description:
        'The public API of a bond_* package read from its source code, for the '
        'version the project resolves: classes, mixins, enums, extensions, '
        'typedefs, functions and variables, with constructors, methods and '
        'fields. Use `symbol` to look up one declaration (e.g. ServiceProvider, '
        'BondFire, FormStateNotifier) or a member name; results are paged.',
    annotations: ToolAnnotations(readOnlyHint: true, openWorldHint: false),
    inputSchema: Schema.object(
      properties: {
        'package': _packageProperty,
        'symbol': Schema.string(
          description:
              'Declaration or member name (exact match first, then '
              'case-insensitive substring). Implies members: true.',
        ),
        'library': Schema.string(
          description:
              'Only declarations exported by this public library, '
              'e.g. validator_localizations.dart.',
        ),
        'detail': EnumSchema.untitledSingleSelect(
          values: ['names', 'signatures', 'docs'],
          defaultValue: 'signatures',
          description: 'names, signatures (default) or signatures with docs.',
        ),
        'members': Schema.bool(
          description:
              'Include constructors, methods and fields (default '
              'false, true when `symbol` is set).',
        ),
        'offset': Schema.int(
          description: 'First declaration (default 0).',
          minimum: 0,
        ),
        'limit': Schema.int(
          description: 'Declarations per page (default 50).',
          minimum: 1,
          maximum: 200,
        ),
        'root': _rootProperty,
      },
      required: ['package'],
      additionalProperties: false,
    ),
  );

  Future<CallToolResult> _apiOutline(CallToolRequest request) => _guard(
    () async {
      final args = request.arguments!;
      final package = await _package(request);
      final symbol = args['symbol'] as String?;
      final page = selectApi(
        _api.extract(package),
        symbol: symbol,
        library: args['library'] as String?,
        offset: (args['offset'] as int?) ?? 0,
        limit: (args['limit'] as int?) ?? 50,
      );
      final detail =
          ApiDetail.values.asNameMap()[args['detail']] ?? ApiDetail.signatures;
      final members =
          (args['members'] as bool?) ?? (symbol != null && symbol.isNotEmpty);
      return _text(renderApi(package, page, detail: detail, members: members));
    },
  );

  static final _nameProperty = Schema.string(
    description: 'Class name in PascalCase.',
  );

  static final _featureProperty = Schema.string(
    description:
        'Feature folder under lib/features/ (snake_case). Defaults to the '
        'name in snake_case.',
  );

  static final _writeAnnotations = ToolAnnotations(
    readOnlyHint: false,
    destructiveHint: false,
    idempotentHint: false,
    openWorldHint: false,
  );

  static final createModelTool = Tool(
    name: 'create_model',
    title: 'Create a Bond model',
    description:
        'Creates a json_serializable model (extends bond_network Model) in '
        'lib/features/<feature>/data/models/. Run build_runner afterwards '
        '(or pass runBuildRunner: true, which can take minutes).',
    annotations: _writeAnnotations,
    inputSchema: Schema.object(
      properties: {
        'name': _nameProperty,
        'feature': _featureProperty,
        'runBuildRunner': Schema.bool(
          description: 'Run `dart run build_runner build` (default false).',
        ),
        'root': _rootProperty,
      },
      required: ['name'],
      additionalProperties: false,
    ),
  );

  static final createWidgetTool = Tool(
    name: 'create_widget',
    title: 'Create a Bond widget',
    description:
        'Creates a widget in lib/features/<feature>/presentation/widgets/: '
        'stateless, stateful or consumer (flutter_riverpod ConsumerWidget).',
    annotations: _writeAnnotations,
    inputSchema: Schema.object(
      properties: {
        'name': _nameProperty,
        'type': EnumSchema.untitledSingleSelect(
          values: widgetTypes,
          defaultValue: 'stateless',
          description: 'Widget kind (default stateless).',
        ),
        'feature': _featureProperty,
        'root': _rootProperty,
      },
      required: ['name'],
      additionalProperties: false,
    ),
  );

  static final createServiceProviderTool = Tool(
    name: 'create_service_provider',
    title: 'Create a Bond service provider',
    description:
        'Creates a bond_core ServiceProvider (with ResponseDecoding) in '
        'lib/features/<feature>/. Register it in lib/app/app.dart afterwards.',
    annotations: _writeAnnotations,
    inputSchema: Schema.object(
      properties: {
        'name': Schema.string(
          description: 'e.g. Profile (creates ProfileServiceProvider).',
        ),
        'feature': _featureProperty,
        'root': _rootProperty,
      },
      required: ['name'],
      additionalProperties: false,
    ),
  );

  static final createProjectTool = Tool(
    name: 'create_project',
    title: 'Create a Flutter Bond project',
    description:
        'Clones the flutter-bond template into <parentDir>/<projectName> and '
        'sets the project name, app name, iOS bundle ID and Android '
        'application ID (flavors add .staging), then makes the first commit.',
    annotations: ToolAnnotations(
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: true,
    ),
    inputSchema: Schema.object(
      properties: {
        'parentDir': Schema.string(
          description: 'Existing folder to create the project in.',
        ),
        'projectName': Schema.string(description: 'snake_case, e.g. my_app.'),
        'bundleId': Schema.string(
          description: 'iOS bundle ID, e.g. com.example.app.',
        ),
        'applicationId': Schema.string(
          description: 'Android application ID (default: the bundle ID).',
        ),
        'appName': Schema.string(
          description:
              'Name on the home screen (default: project name in Title Case).',
        ),
        'templateUrl': Schema.string(
          description:
              'Git URL or local path of the template '
              '(default https://github.com/flutterbond/flutter-bond.git).',
        ),
        'ref': Schema.string(
          description: 'Template tag or branch (default v2.0.0).',
        ),
        'pubGet': Schema.bool(
          description: 'Run `flutter pub get` afterwards (default false).',
        ),
      },
      required: ['parentDir', 'projectName', 'bundleId'],
      additionalProperties: false,
    ),
  );

  Future<CallToolResult> _createModel(CallToolRequest request) =>
      _guard(() async {
        final args = request.arguments!;
        return _generated(
          await generateModel(
            project: await _writableProject(request),
            name: args['name'] as String,
            feature: args['feature'] as String?,
            runBuildRunner: (args['runBuildRunner'] as bool?) ?? false,
          ),
        );
      });

  Future<CallToolResult> _createWidget(CallToolRequest request) =>
      _guard(() async {
        final args = request.arguments!;
        return _generated(
          await generateWidget(
            project: await _writableProject(request),
            name: args['name'] as String,
            type: (args['type'] as String?) ?? 'stateless',
            feature: args['feature'] as String?,
          ),
        );
      });

  Future<CallToolResult> _createServiceProvider(CallToolRequest request) =>
      _guard(() async {
        final args = request.arguments!;
        return _generated(
          await generateServiceProvider(
            project: await _writableProject(request),
            name: args['name'] as String,
            feature: args['feature'] as String?,
          ),
        );
      });

  Future<CallToolResult> _createProject(CallToolRequest request) =>
      _guard(() async {
        final args = request.arguments!;
        final parent = Directory(_toPath(args['parentDir'] as String));
        if (!parent.existsSync()) {
          throw ToolError('Directory not found: ${parent.path}');
        }
        await _requireInsideRoots(parent);
        return _generated(
          await generateProject(
            parent: parent,
            projectName: args['projectName'] as String,
            bundleId: args['bundleId'] as String,
            applicationId: args['applicationId'] as String?,
            appName: args['appName'] as String?,
            templateUrl:
                (args['templateUrl'] as String?) ??
                'https://github.com/flutterbond/flutter-bond.git',
            ref: (args['ref'] as String?) ?? 'v2.0.0',
            pubGet: (args['pubGet'] as bool?) ?? false,
          ),
        );
      });

  /// The project a generator writes into: a Dart project inside the client roots.
  Future<Directory> _writableProject(CallToolRequest request) async {
    final dir = await projectDirectory(request.arguments?['root'] as String?);
    if (!File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      throw ToolError(
        '${dir.path} is not a Dart/Flutter project (no pubspec.yaml).',
      );
    }
    await _requireInsideRoots(dir);
    return dir;
  }

  /// Rejects directories outside the client's roots (when it reports roots).
  Future<void> _requireInsideRoots(Directory dir) async {
    if (!supportsRoots) return;
    final clientRoots = [
      for (final root in await roots) p.normalize(_toPath(root.uri)),
    ];
    final path = p.normalize(dir.absolute.path);
    final inside = clientRoots.any(
      (root) => p.equals(root, path) || p.isWithin(root, path),
    );
    if (inside) return;
    throw ToolError(
      '$path is outside the client roots: ${clientRoots.join(', ')}.',
    );
  }

  static CallToolResult _generated(GeneratorResult result) {
    final text = StringBuffer('Created:\n');
    for (final file in result.files) {
      text.writeln('- $file');
    }
    if (result.followUp.isNotEmpty) {
      text.writeln('\nNext:');
      for (final line in result.followUp) {
        text.writeln('- $line');
      }
    }
    return CallToolResult(
      content: [TextContent(text: text.toString())],
      structuredContent: result.toJson(),
    );
  }

  Future<CallToolResult> _packages(CallToolRequest request) => _guard(() async {
    final resolved = await _resolve(request);
    final data = {
      'resolvedFrom': resolved.resolvedFrom(),
      'packages': [for (final package in resolved.packages) package.toJson()],
    };
    final text = StringBuffer('Bond packages of ${resolved.projectRoot}:\n');
    if (resolved.packages.isEmpty) text.writeln('(none)');
    for (final package in resolved.packages) {
      text.writeln(
        '- ${package.name} ${package.version} (${package.source.name}): '
        '${package.description}',
      );
    }
    return CallToolResult(
      content: [
        TextContent(text: text.toString()),
        TextContent(text: jsonEncode(data)),
      ],
      structuredContent: data,
    );
  });

  Future<CallToolResult> _packageOverview(CallToolRequest request) =>
      _guard(() async {
        final package = await _package(request);
        final sections = (request.arguments?['changelogSections'] as int?) ?? 2;
        return _text(packageOverview(package, changelogSections: sections));
      });

  Future<CallToolResult> _migration(CallToolRequest request) =>
      _guard(() async {
        final name = request.arguments?['package'] as String?;
        final package = name == null ? null : await _package(request);
        return _text(
          migrationNotes(
            package: package,
            from: request.arguments?['from'] as String?,
            to: request.arguments?['to'] as String?,
          ),
        );
      });

  void _addResources() {
    addResource(
      Resource(
        uri: 'bond://docs/migration/packages',
        name: 'Migration guide of the bond_* packages',
        mimeType: 'text/markdown',
      ),
      (request) => _markdown(request.uri, packagesMigrationGuide),
    );
    addResource(
      Resource(
        uri: 'bond://docs/migration/template',
        name: 'Migration guide of the flutter-bond template',
        mimeType: 'text/markdown',
      ),
      (request) => _markdown(request.uri, templateMigrationGuide),
    );
    addResourceTemplate(
      ResourceTemplate(
        uriTemplate: 'bond://package/{name}/{document}',
        name: 'Bond package document',
        title: 'README, CHANGELOG or example of a bond_* package',
        description: 'document is one of: readme, changelog, example.',
        mimeType: 'text/markdown',
      ),
      _readPackageResource,
    );
  }

  Future<ReadResourceResult?> _readPackageResource(
    ReadResourceRequest request,
  ) async {
    final uri = Uri.parse(request.uri);
    if (uri.scheme != 'bond' ||
        uri.host != 'package' ||
        uri.pathSegments.length != 2) {
      return null;
    }
    final document = PackageDocument.values.asNameMap()[uri.pathSegments[1]];
    if (document == null) return null;
    final resolved = await locator.locate(await projectDirectory(null));
    final package = resolved.find(uri.pathSegments[0]);
    if (package == null) return null;
    final text = readPackageDocument(package, document);
    if (text == null) return null;
    return _markdown(request.uri, text);
  }

  /// The project a request is about: explicit `root` → the first client root
  /// with a package config → the first client root → `--project` → cwd.
  Future<Directory> projectDirectory(String? root) async {
    if (root != null && root.isNotEmpty) {
      final dir = Directory(_toPath(root));
      if (!dir.existsSync()) {
        throw ToolError('Directory not found: ${dir.path}');
      }
      return dir;
    }
    if (supportsRoots) {
      final clientRoots = await roots;
      for (final clientRoot in clientRoots) {
        final dir = Directory(_toPath(clientRoot.uri));
        if (BondPackageLocator.findPackageConfigFile(dir) != null) return dir;
      }
      if (clientRoots.isNotEmpty) {
        return Directory(_toPath(clientRoots.first.uri));
      }
    }
    return projectFallback ?? Directory.current;
  }

  Future<ResolvedBondPackages> _resolve(CallToolRequest request) async =>
      locator.locate(
        await projectDirectory(request.arguments?['root'] as String?),
      );

  Future<BondPackage> _package(CallToolRequest request) async {
    final name = request.arguments!['package'] as String;
    final resolved = await _resolve(request);
    final package = resolved.find(name);
    if (package != null) return package;
    final known = resolved.packages.map((p) => p.name).join(', ');
    throw ToolError(
      '$name is not a dependency of ${resolved.projectRoot}. '
      'Bond packages there: ${known.isEmpty ? 'none' : known}.',
    );
  }

  static String _toPath(String rootOrUri) => rootOrUri.startsWith('file:')
      ? Uri.parse(rootOrUri).toFilePath()
      : p.absolute(rootOrUri);

  static CallToolResult _text(String text) =>
      CallToolResult(content: [TextContent(text: text)]);

  static ReadResourceResult _markdown(String uri, String text) =>
      ReadResourceResult(
        contents: [
          TextResourceContents(uri: uri, text: text, mimeType: 'text/markdown'),
        ],
      );

  /// Turns expected failures into readable tool errors instead of stack traces.
  static Future<CallToolResult> _guard(
    Future<CallToolResult> Function() body,
  ) async {
    try {
      return await body();
    } on ToolError catch (error) {
      return _error(error.message);
    } on PackageConfigNotFound catch (error) {
      return _error(error.toString());
    } on FileSystemException catch (error) {
      return _error('${error.message}: ${error.path}');
    } on GeneratorInputError catch (error) {
      return _error(error.message);
    } on Exception catch (error) {
      // e.g. "<path> already exists." or a failed git/flutter process.
      return _error('$error'.replaceFirst('Exception: ', ''));
    }
  }

  static CallToolResult _error(String message) =>
      CallToolResult(isError: true, content: [TextContent(text: message)]);
}
