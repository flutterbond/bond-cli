import 'package:bond_cli/core/utils.dart';
import 'package:meta/meta.dart';

import 'actionable.dart';

abstract class Task<T> with Actionable<T> {
  final _warnings = <String>[];

  @override
  Future<T> run() async {
    final progress = logger.progress(actionDescription);
    try {
      final results = await execute();
      progress.complete();
      return results;
    } catch (_) {
      progress.fail();
      rethrow;
    } finally {
      // Printed after the spinner line so they don't garble it.
      _warnings.forEach(logger.warn);
      _warnings.clear();
    }
  }

  /// Queues a warning that is printed once the task's spinner has finished.
  @protected
  void warn(String message) => _warnings.add(message);

  @protected
  @override
  Future<T> execute();
}
