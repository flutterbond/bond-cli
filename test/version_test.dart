import 'dart:io';

import 'package:bond_cli/version.dart';
import 'package:test/test.dart';

void main() {
  test('bondCliVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(bondCliVersion, version);
  });
}
