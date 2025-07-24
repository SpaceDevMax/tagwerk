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
        
        // Default sort by 'order' ascending if no custom comparator
        // Will be overwritten by sorts like 'done' in the next block
        if (comparator == null && filteredIndices.isNotEmpty) {
          filteredIndices.sort((aIdx, bIdx) {
            final aOrder = box.getAt(aIdx)?['order'] as double? ?? 0.0;
            final bOrder = box.getAt(bIdx)?['order'] as double? ?? 0.0;
            return aOrder.compareTo(bOrder);
          });
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
            : (comparator == null
                ? ReorderableListView.builder(  // Use Reorderable only if no custom comparator (e.g., not for "Done" view)
                    itemCount: filteredIndices.length,
                    onReorder: (int oldIndex, int newIndex) {
                      // Update the 'order' field of the moved todo to fit between neighbors
                      final int originalNewIndex = newIndex;
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final int realOld = filteredIndices[oldIndex];
                      final todo = box.getAt(realOld);
                      final updatedTodo = Map<String, dynamic>.from(todo ?? {});
                      double newOrder;
                      if (originalNewIndex == filteredIndices.length) {
                        final lastReal = filteredIndices[filteredIndices.length - 1];
                        final lastOrder = box.getAt(lastReal)!['order'] as double? ?? 0.0;
                        newOrder = lastOrder + 1;
                      } else if (newIndex == 0) {
                        final firstReal = filteredIndices[0];
                        final firstOrder = box.getAt(firstReal)!['order'] as double? ?? 0.0;
                        newOrder = firstOrder - 1;
                      } else {
                        final prevReal = filteredIndices[newIndex - 1];
                        final nextReal = filteredIndices[newIndex];
                        final prevOrder = box.getAt(prevReal)!['order'] as double? ?? 0.0;
                        final nextOrder = box.getAt(nextReal)!['order'] as double? ?? 0.0;
                        newOrder = (prevOrder + nextOrder) / 2;
                      }
                      updatedTodo['order'] = newOrder;
                      box.putAt(realOld, updatedTodo);
                    },
                    itemBuilder: (context, idx) {
                      final int realIndex = filteredIndices[idx];
                      final todo = box.getAt(realIndex)!;
                      String dueStr = '';
                      final dueMs = todo['dueDate'] as int?;
                      if (dueMs != null) {
                        final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
                        dueStr = ' - Due: ${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
                      }

                      bool isDueToday = false;
                      if (dueMs != null) {
                        final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
                        final now = DateTime.now();
                        isDueToday = due.year == now.year && due.month == now.month && due.day == now.day;
                      }

                      int? groupId = todo['groupId'] as int?;
                      Color? taskColor;
                      if (groupId != null) {
                        final group = todoService.groupBox.getAt(groupId);
                        taskColor = group != null ? Color(group['color'] as int) : null;
                      }

                      return ListTile(
                        key: ValueKey(todo['id']),  // Use unique 'id' for stable reordering
                        title: Text(
                          todo['title'] ?? '',
                          style: TextStyle(
                            decoration: todo['isDone'] == true ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          (todo['description'] ?? '') + dueStr,
                          style: TextStyle(
                            decoration: todo['isDone'] == true ? TextDecoration.lineThrough : null,
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
                              value: todo['isDone'] ?? false,
                              onChanged: (value) {
                                final updatedTodo = Map<String, dynamic>.from(todo);
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
                              icon: Icon(isDueToday ? Icons.today : Icons.calendar_month_outlined),
                              onPressed: () {
                                todoService.toggleDueToday(realIndex);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                final initialDue = dueMs != null ? DateTime.fromMillisecondsSinceEpoch(dueMs) : null;
                                TaskDialog(
                                  todoService: todoService,
                                  initialTitle: todo['title'],
                                  initialDescription: todo['description'],
                                  initialDueDate: initialDue,
                                  initialGroupId: todo['groupId'],
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
                            Padding(
                              padding: const EdgeInsets.only(left: 15.0),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : ListView.builder(  // Fallback to original ListView if comparator is present (e.g., "Done" view)
                    itemCount: filteredIndices.length,
                    itemBuilder: (context, idx) {
                      // ... (keep the existing itemBuilder code here, unchanged, but update key to ValueKey(todo?['id']) for consistency)
                      // Specifically, in the ListTile: key: ValueKey(todo?['id']),
                      // Rest remains the same
                      final int realIndex = filteredIndices[idx];
                      final todo = box.getAt(realIndex)!;  // Non-null: Hive returns valid map
                      String dueStr = '';
                      final dueMs = todo['dueDate'] as int?;
                      if (dueMs != null) {
                        final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
                        dueStr = ' - Due: ${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
                      }

                      bool isDueToday = false;
                      if (dueMs != null) {
                        final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
                        final now = DateTime.now();
                        isDueToday = due.year == now.year && due.month == now.month && due.day == now.day;
                      }

                      int? groupId = todo['groupId'] as int?;
                      Color? taskColor;
                      if (groupId != null) {
                        final group = todoService.groupBox.getAt(groupId);
                        taskColor = group != null ? Color(group['color'] as int) : null;
                      }

                      return ListTile(
                        key: ValueKey(todo['id']),  // Non-null: 'id' set in addTask
                        title: Text(
                          todo['title'] ?? '',
                          style: TextStyle(
                            decoration: todo['isDone'] == true ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          (todo['description'] ?? '') + dueStr,
                          style: TextStyle(
                            decoration: todo['isDone'] == true ? TextDecoration.lineThrough : null,
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
                              value: todo['isDone'] ?? false,
                              onChanged: (value) {
                                final updatedTodo = Map<String, dynamic>.from(todo);
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
                              icon: Icon(isDueToday ? Icons.today : Icons.calendar_month_outlined),
                              onPressed: () {
                                todoService.toggleDueToday(realIndex);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                final initialDue = dueMs != null ? DateTime.fromMillisecondsSinceEpoch(dueMs) : null;
                                TaskDialog(
                                  todoService: todoService,
                                  initialTitle: todo['title'],
                                  initialDescription: todo['description'],
                                  initialDueDate: initialDue,
                                  initialGroupId: todo['groupId'],
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
                  )
              );
      }        
    );
  }
}