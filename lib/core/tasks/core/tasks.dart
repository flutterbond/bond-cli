import 'package:bond_cli/core/utils.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';

import 'actionable.dart';
import 'task.dart';

abstract class Tasks with Actionable<void> {
  List<Task> get tasks;

  @override
  Future<void> run() async {
    logger.info(styleBold.wrap(actionDescription));
    await execute();
  }

  @protected
  @override
  Future<void> execute() async {
    for (final task in tasks) {
      await task.run();
    }
  }
}
