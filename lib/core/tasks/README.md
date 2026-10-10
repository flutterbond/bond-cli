# Creating and Using Tasks in Bond CLI

Bond CLI leverages the concept of `Tasks` and `Task` to structure its command execution sequence. Here's how you can utilize them to build robust commands for your CLI.

## Step 1: Understanding `Task` and `Tasks`

### 1.1 What is a `Task`?
A `Task` is a single unit of work or operation. In Bond CLI, it encapsulates a specific action along with its description and how it should be executed.

### 1.2 What are `Tasks`?
`Tasks` is essentially a group of `Task` instances. It's useful when a command involves multiple steps or operations, which should be executed in a particular sequence.

## Step 2: Creating a `Task`

Here's a simple way to create a new `Task`:

1. **Define your Task Class**: 
   This class should extend the `Task` abstract class.

```dart
class MySampleTask extends Task<void> {
  @override
  String get actionDescription => 'Description of your task';

  @override
  Future<void> execute() async {
    // Your task execution logic here.
  }
}
```

2. Implement the required methods:
   - `actionDescription`: A brief description of the task.
   - `execute`: The main logic of the task.

## Step 3: Grouping Tasks

If you have multiple tasks that should be executed in sequence for a particular command, group them into a `Tasks` class:

```dart
class GroupedTasks extends Tasks {
  @override
  String get actionDescription => 'Description of grouped tasks';

  @override
  List<Task> get tasks => [
        Task1(),
        Task2(),
        // ... add more tasks as needed.
      ];
}
```

Remember to provide the `actionDescription` and define the list of tasks in the `tasks` getter.

## Step 4: Using Tasks in Commands

Now that you've defined your tasks, you can utilize them within a command:

```dart
class MySampleCommand extends Command<void> {
  @override
  String get name => 'sample-command';

  @override
  String get description => 'Description of your command.';

  @override
  Future<void> run() async {
    final myTask = MySampleTask();
    await myTask.run();

    final myGroupedTasks = GroupedTasks();
    await myGroupedTasks.run();
  }
}
```

Here, we've defined a new command named `sample-command`. In the `run` method, we're executing the `MySampleTask` and then the `GroupedTasks`.

## Step 5: Adding Command to Bond CLI

Finally, register your command with the Bond CLI:

```dart
import 'package:bond_cli/commands/bond_command_runner.dart';

void main(List<String> arguments) {
  final app = BondCommandRunner()
    ..addCommand(MySampleCommand());
  app.run(arguments);
}
```
