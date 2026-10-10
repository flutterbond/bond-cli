import 'package:bond_cli/core/utils/string_extensions.dart';
import 'package:test/test.dart';

void main() {
  test('toSnakeCase splits PascalCase, acronyms, digits and spaces', () {
    expect('UserDetail'.toSnakeCase(), 'user_detail');
    expect('userDetail'.toSnakeCase(), 'user_detail');
    expect('HTTPClientError'.toSnakeCase(), 'http_client_error');
    expect('Post2Comment'.toSnakeCase(), 'post2_comment');
    expect('My Dream Project'.toSnakeCase(), 'my_dream_project');
    expect('my-app'.toSnakeCase(), 'my_app');
    expect('already_snake'.toSnakeCase(), 'already_snake');
  });

  test('toPascalCase and toTitleCase', () {
    expect('user_detail'.toPascalCase(), 'UserDetail');
    expect('UserDetail'.toPascalCase(), 'UserDetail');
    expect('my_dream_project'.toTitleCase(), 'My Dream Project');
  });
}
