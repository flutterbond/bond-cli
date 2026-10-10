/// A bond_core `ServiceProvider` that also decodes the feature's models
/// through `ResponseDecoding.factories`.
String serviceProviderStub(String className) {
  return '''
import 'package:bond_core/bond_core.dart';
import 'package:get_it/get_it.dart';

class $className extends ServiceProvider with ResponseDecoding {
  @override
  Future<void> register(GetIt it) async {
    // Register the feature's dependencies, e.g.
    // it.registerFactory(() => PostsApi(it()));
  }

  @override
  Map<Type, JsonFactory> get factories => {
    // Map each model to its JSON factory, e.g.
    // Post: Post.fromJson,
  };
}
''';
}
