// widgets/task_tile.dart
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/todo_service.dart';
import 'task_dialog.dart';

class TaskTile extends StatelessWidget {
  final TodoService todoService;
  final int todoId;
  final Todo todo;
  final bool showDragHandle;

  const TaskTile({
    super.key,
    required this.todoService,
    required this.todoId,
    required this.todo,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    String dueStr = '';
    final dueMs = todo.dueDate;
    bool isOverdue = false;
    if (dueMs != null) {
      final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
      dueStr = ' - Due: ${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
      final today = DateTime.now();
      isOverdue = !todo.isDone && due.isBefore(DateTime(today.year, today.month, today.day));
    }

    bool isDueToday = false;
    if (dueMs != null) {
      final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
      final now = DateTime.now();
      isDueToday = due.year == now.year && due.month == now.month && due.day == now.day;
    }

    int? groupId = todo.groupId;
    Color? taskColor;
    if (groupId != null) {
      final group = todoService.isar.groups.getSync(groupId);
      taskColor = group != null ? Color(group.color) : null;
    }

    final subtasks = todo.subtasks;
    final completedSubs = subtasks.where((sub) => sub.isDone).length;
    final subCountStr = subtasks.isNotEmpty ? ' | Subtasks: $completedSubs/${subtasks.length}' : '';

    return ExpansionTile(
      key: ValueKey(todo.id),
      title: Text(
        todo.title,
        style: TextStyle(
          decoration: todo.isDone ? TextDecoration.lineThrough : null,
          color: isOverdue ? const Color.fromARGB(255, 122, 10, 1) : null,
        ),
      ),
      subtitle: Text(
        (todo.description) + dueStr + subCountStr,
        style: TextStyle(
          decoration: todo.isDone ? TextDecoration.lineThrough : null,
          color: isOverdue ? const Color.fromARGB(255, 122, 10, 1) : null,
        ),
      ),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (taskColor != null) ...[
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: taskColor,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Checkbox(
            value: todo.isDone,
            onChanged: (value) async {
              final newIsDone = value ?? false;
              if (newIsDone && subtasks.isNotEmpty && !todoService.areAllSubtasksDone(todoId)) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm'),
                    content: const Text('Are you sure? There are still open subtasks. All subtasks will be closed.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                    ],
                  ),
                );
                if (confirm == true) {
                  todoService.markAllSubtasksDone(todoId);
                  todoService.updateIsDone(todoId, true);
                }
              } else {
                todoService.updateIsDone(todoId, newIsDone);
              }
            },
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(isDueToday ? Icons.today : Icons.calendar_month_outlined),
            onPressed: () {
              todoService.toggleDueToday(todoId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              final initialDue = todo.dueDate != null ? DateTime.fromMillisecondsSinceEpoch(todo.dueDate!) : null;
              TaskDialog(
                todoService: todoService,
                initialTitle: todo.title,
                initialDescription: todo.description,
                initialDueDate: initialDue,
                initialGroupId: todo.groupId,
                initialSubtasks: todo.subtasks,
                onSave: (title, description, dueDate, groupId, subtasks) {
                  todoService.editTask(todoId, title, description, dueDate, subtasks, groupId);
                },
                dialogTitle: 'Edit Task',
                saveButtonText: 'Update',
              ).show(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              todoService.deleteTask(todoId);
            },
          ),
          if (showDragHandle)
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.drag_handle),
            ),
        ],
      ),
      children: [
        ...todo.subtasks.asMap().entries.map((entry) {
          final subIdx = entry.key;
          final sub = entry.value;
          return ListTile(
            title: Text(sub.title),
            leading: Checkbox(
              value: sub.isDone,
              onChanged: (subValue) {
                final newSubDone = subValue ?? false;
                todoService.toggleSubtask(todoId, subIdx, newSubDone);
                if (newSubDone && todoService.areAllSubtasksDone(todoId) && !todo.isDone) {
                  todoService.updateIsDone(todoId, true);
                }
              },
            ),
          );
        }),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Add Subtask'),
          onTap: () {
            final subController = TextEditingController();
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Add Subtask'),
                content: TextField(
                  controller: subController,
                  decoration: const InputDecoration(hintText: 'Subtask title'),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () {
                      todoService.addSubtask(todoId, subController.text);
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}