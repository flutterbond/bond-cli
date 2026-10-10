import 'package:bond_cli/core/utils.dart';

/// A json_serializable model extending bond_network's `Model`, so it works
/// with `SingleResponse<T>` and `ListResponse<T>`. Run build_runner to
/// generate the `.g.dart` part.
String modelStub(String className) {
  final fileName = className.toSnakeCase();
  return '''
import 'package:bond_network/bond_network.dart';
import 'package:json_annotation/json_annotation.dart';

part '$fileName.g.dart';

@JsonSerializable()
class $className extends Model {
  const $className({required super.id});

  factory $className.fromJson(Map<String, dynamic> json) =>
      _\$${className}FromJson(json);

  @override
  Map<String, dynamic> toJson() => _\$${className}ToJson(this);

  @override
  List<Object?> get props => [id];
}
''';
}
