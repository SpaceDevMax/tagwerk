import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/todo_service.dart';
import '../widgets/task_dialog.dart';

class TodoBuilder extends StatelessWidget {
  const TodoBuilder({
    super.key,
    required this.todoService,
    this.filter,
    this.comparator,
  });

  final TodoService todoService;
  final bool Function(Map? todo)? filter;
  final int Function(Map, Map)? comparator;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: todoService.todoBox.listenable(),
      builder: (context, Box<Map> box, _) {
        List<int> filteredIndices = [];
        for (int i = 0; i < box.length; i++) {
          final todo = box.getAt(i);
          bool include = true;
          if (filter != null) {
            include = filter!(todo);
          }
          if (include) {
            filteredIndices.add(i);
          }
        }
        
        // List sorting mechanism (latest Dones appear first in the Done list)
        if (comparator != null && filteredIndices.isNotEmpty) {
          filteredIndices.sort((aIdx, bIdx) {
            final a = box.getAt(aIdx)!;
            final b = box.getAt(bIdx)!;
            return comparator!(a, b);
          });
        }

        return filteredIndices.isEmpty
            ? const Center(child: Text('No tasks yet. Add one!'))
            : ListView.builder(
                itemCount: filteredIndices.length,
                itemBuilder: (context, idx) {
                  final int realIndex = filteredIndices[idx];
                  final todo = box.getAt(realIndex);
                  String dueStr = '';
                  final dueMs = todo?['dueDate'] as int?;
                  if (dueMs != null) {
                    final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
                    dueStr = ' - Due: ${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
                  }

                  int? groupId = todo?['groupId'] as int?;
                  Color? taskColor;
                  if (groupId != null) {
                    final group = todoService.groupBox.getAt(groupId);
                    taskColor = group != null ? Color(group['color'] as int) : null;
                  }

                  return ListTile(
                    title: Text(
                      todo?['title'] ?? '',
                      style: TextStyle(
                        decoration: todo?['isDone'] == true ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      (todo?['description'] ?? '') + dueStr,
                      style: TextStyle(
                        decoration: todo?['isDone'] == true ? TextDecoration.lineThrough : null,
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
                          value: todo?['isDone'] ?? false,
                          onChanged: (value) {
                            final updatedTodo = Map<String, dynamic>.from(todo ?? {});
                            final newIsDone = value ?? false;
                            updatedTodo['isDone'] = newIsDone;
                            if (newIsDone) {
                              if (updatedTodo['completedAt'] == null) {
                                updatedTodo['completedAt'] = DateTime.now().millisecondsSinceEpoch;
                              }
                            } else {
                              updatedTodo['completedAt'] = null;  // Reset when unchecked
                            }
                            box.putAt(realIndex, updatedTodo);
                          },
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            final initialDue = dueMs != null ? DateTime.fromMillisecondsSinceEpoch(dueMs) : null;
                            TaskDialog(
                              todoService: todoService,
                              initialTitle: todo?['title'],
                              initialDescription: todo?['description'],
                              initialDueDate: initialDue,
                              initialGroupId: todo?['groupId'],
                              onSave: (title, description, dueDate, groupId) {
                                todoService.editTask(realIndex, title, description, dueDate, groupId);
                              },
                              dialogTitle: 'Edit Task',
                              saveButtonText: 'Update',
                            ).show(context);                          
                          },
                        ),
                        IconButton( 
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            todoService.deleteTask(realIndex);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
      },
    );
  }
}