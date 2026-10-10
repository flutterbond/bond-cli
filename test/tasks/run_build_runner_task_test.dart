import 'package:bond_cli/core/tasks/create_feature/common_tasks/run_build_runner_task.dart';
import 'package:test/test.dart';

void main() {
  test('runs a full build_runner build without --build-filter', () {
    // With --build-filter, build_runner 2.16 deletes every other generated
    // file of the project (post.g.dart, user.g.dart, ...).
    expect(RunBuildRunnerTask.arguments, ['run', 'build_runner', 'build']);
    expect(
      RunBuildRunnerTask.arguments.where((a) => a.startsWith('--build-filter')),
      isEmpty,
    );
  });
}
