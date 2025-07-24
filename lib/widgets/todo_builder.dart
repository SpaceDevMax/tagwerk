import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/todo_service.dart';
import '../widgets/task_dialog.dart';

class TodoBuilder extends StatefulWidget {
  const TodoBuilder({
    super.key,
    required this.todoService,
    this.filter,
  });

  final TodoService todoService;
  final bool Function(Map? todo)? filter;

  @override
  State<TodoBuilder> createState() => _TodoBuilderState();
}

class _TodoBuilderState extends State<TodoBuilder> {
  String _sortOption = 'due_asc';  // Default to due next to due last

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.todoService.todoBox.listenable(),
      builder: (context, Box<Map> box, _) {
        List<int> filteredIndices = [];
        for (int i = 0; i < box.length; i++) {
          final todo = box.getAt(i);
          bool include = true;
          if (widget.filter != null) {
            include = widget.filter!(todo);
          }
          if (include) {
            filteredIndices.add(i);
          }
        }

        if (filteredIndices.isNotEmpty) {
          filteredIndices.sort((aIdx, bIdx) {
            final a = box.getAt(aIdx)!;
            final b = box.getAt(bIdx)!;
            if (_sortOption == 'custom') {
              final aOrder = a['order'] as double? ?? 0.0;
              final bOrder = b['order'] as double? ?? 0.0;
              return aOrder.compareTo(bOrder);
            }
            switch (_sortOption) {
              case 'created_desc':  // Latest to oldest
                return int.parse(b['id'] as String).compareTo(int.parse(a['id'] as String));
              case 'created_asc':  // Oldest to latest
                return int.parse(a['id'] as String).compareTo(int.parse(b['id'] as String));
              case 'due_asc':  // Due next to due last (nulls last)
                final large = 9223372036854775807;
                final aDue = a['dueDate'] as int? ?? large;
                final bDue = b['dueDate'] as int? ?? large;
                return aDue.compareTo(bDue);
              default:
                return 0;
            }
          });
        }

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DropdownButton<String>(
                  value: _sortOption,
                  onChanged: (newValue) {
                    setState(() {
                      _sortOption = newValue!;
                    });
                  },
                  items: const [
                    DropdownMenuItem(value: 'custom', child: Text('Custom')),
                    DropdownMenuItem(value: 'created_desc', child: Text('Latest to Oldest')),
                    DropdownMenuItem(value: 'created_asc', child: Text('Oldest to Latest')),
                    DropdownMenuItem(value: 'due_asc', child: Text('Due Next to Due Last')),
                  ],
                ),
              ],
            ),
            Expanded(
              child: filteredIndices.isEmpty
                  ? const Center(child: Text('No tasks yet. Add one!'))
                  : (_sortOption == 'custom'
                      ? ReorderableListView.builder(
                          itemCount: filteredIndices.length,
                          onReorder: (int oldIndex, int newIndex) {
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
                              final group = widget.todoService.groupBox.getAt(groupId);
                              taskColor = group != null ? Color(group['color'] as int) : null;
                            }

                            return ListTile(
                              key: ValueKey(todo['id']),
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
                                        updatedTodo['completedAt'] = null;
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
                                      widget.todoService.toggleDueToday(realIndex);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {
                                      final initialDue = dueMs != null ? DateTime.fromMillisecondsSinceEpoch(dueMs) : null;
                                      TaskDialog(
                                        todoService: widget.todoService,
                                        initialTitle: todo['title'],
                                        initialDescription: todo['description'],
                                        initialDueDate: initialDue,
                                        initialGroupId: todo['groupId'],
                                        onSave: (title, description, dueDate, groupId) {
                                          widget.todoService.editTask(realIndex, title, description, dueDate, groupId);
                                        },
                                        dialogTitle: 'Edit Task',
                                        saveButtonText: 'Update',
                                      ).show(context);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      widget.todoService.deleteTask(realIndex);
                                    },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 15.0),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          itemCount: filteredIndices.length,
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
                              final group = widget.todoService.groupBox.getAt(groupId);
                              taskColor = group != null ? Color(group['color'] as int) : null;
                            }

                            return ListTile(
                              key: ValueKey(todo['id']),
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
                                        updatedTodo['completedAt'] = null;
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
                                      widget.todoService.toggleDueToday(realIndex);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {
                                      final initialDue = dueMs != null ? DateTime.fromMillisecondsSinceEpoch(dueMs) : null;
                                      TaskDialog(
                                        todoService: widget.todoService,
                                        initialTitle: todo['title'],
                                        initialDescription: todo['description'],
                                        initialDueDate: initialDue,
                                        initialGroupId: todo['groupId'],
                                        onSave: (title, description, dueDate, groupId) {
                                          widget.todoService.editTask(realIndex, title, description, dueDate, groupId);
                                        },
                                        dialogTitle: 'Edit Task',
                                        saveButtonText: 'Update',
                                      ).show(context);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      widget.todoService.deleteTask(realIndex);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        )),
            ),
          ],
        );
      },
    );
  }
}