// widgets/task_dialog.dart
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/todo_service.dart';
import 'group_dialog.dart';

class TaskDialog extends StatelessWidget {
  final TodoService todoService;
  final String? initialTitle;
  final String? initialDescription;
  final DateTime? initialDueDate;
  final int? initialGroupId;
  final List<Subtask> initialSubtasks;
  final void Function(String title, String description, DateTime dueDate, int? groupId, List<Subtask> subtasks) onSave;
  final String dialogTitle;
  final String saveButtonText;

  const TaskDialog({
    super.key,
    required this.todoService,
    this.initialTitle,
    this.initialDescription,
    this.initialDueDate,
    this.initialGroupId,
    this.initialSubtasks = const [],
    required this.onSave,
    this.dialogTitle = 'Add Task',
    this.saveButtonText = 'Add',
  });

  void show(BuildContext context) {
    final TextEditingController titleController = TextEditingController(text: initialTitle ?? '');
    final TextEditingController descriptionController = TextEditingController(text: initialDescription ?? '');
    DateTime? selectedDate = initialDueDate;
    int? selectedGroupId = initialGroupId;
    List<Subtask> selectedSubtasks = initialSubtasks.map((s) => s.copyWith()).toList();
    

    showDialog(
      context: context,
      builder: (BuildContext outerContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter dialogSetState) {
            return AlertDialog(
              title: Text(dialogTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(hintText: 'Enter task title'),
                      autofocus: true,
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(hintText: 'Enter description'),
                      onSubmitted: (_) {
                        if (titleController.text.isNotEmpty && selectedDate != null) {
                          onSave(titleController.text, descriptionController.text, selectedDate!, selectedGroupId, selectedSubtasks);
                          Navigator.of(outerContext).pop();
                        }
                      }
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedDate == null
                              ? 'No due date selected (required)'
                              : 'Due: ${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate != null && !selectedDate!.isBefore(DateTime.now())
                                  ? selectedDate!
                                  : DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              dialogSetState(() => selectedDate = picked);
                            }
                          },
                          child: const Text('Pick Date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Group>>(
                      future: todoService.getGroups(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();
                        final groups = snapshot.data!;
                        // Ensure selectedGroupId is valid
                        final validGroupId = groups.any((group) => group.id == selectedGroupId) ? selectedGroupId : null;
                        return DropdownButton<int?>(
                          value: validGroupId,
                          hint: const Text('Select Group'),
                          items: groups.map((group) {
                            return DropdownMenuItem<int?>(
                              value: group.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    color: Color(group.color),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(group.name),
                                ],
                              ),
                            );
                          }).toList()
                            ..add(const DropdownMenuItem<int?>(value: null, child: Text('No Group')))
                            ..add(const DropdownMenuItem<int?>(value: -1, child: Text('Create New Group'))),
                          onChanged: (value) async {
                            if (value == -1) {
                              GroupDialog(
                                todoService: todoService,
                                onSave: (name, color) async {
                                  final newId = await todoService.addGroup(name, color);
                                  dialogSetState(() {
                                    selectedGroupId = newId;
                                  });
                                },
                              ).show(dialogContext);
                            } else {
                              dialogSetState(() => selectedGroupId = value);
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Subtasks:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Column(
                      children: selectedSubtasks.asMap().entries.map((entry) {
                        int index = entry.key;
                        Subtask sub = entry.value;
                        return ListTile(
                          title: TextField(
                            controller: TextEditingController(text: sub.title),
                            onChanged: (newTitle) {
                              dialogSetState(() => selectedSubtasks[index] = sub.copyWith(title: newTitle));
                            },
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: sub.isDone,
                                onChanged: (newValue) {
                                  dialogSetState(() => selectedSubtasks[index] = sub.copyWith(isDone: newValue ?? false));
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () {
                                  dialogSetState(() => selectedSubtasks.removeAt(index));
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final subController = TextEditingController();
                        showDialog(
                          context: dialogContext,
                          builder: (ctx) => AlertDialog(
                            title: Text('Add Subtask'),
                            content: TextField(controller: subController, decoration: InputDecoration(hintText: 'Subtask title')),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                              TextButton(
                                onPressed: () {
                                  if (subController.text.isNotEmpty) {
                                    dialogSetState(() => selectedSubtasks.add(Subtask(title: subController.text)));
                                  }
                                  Navigator.pop(ctx);
                                },
                                child: Text('Add'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text('Add Subtask'),
                    ),
                  ],
                )
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(outerContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty && selectedDate != null) {
                      onSave(
                        titleController.text,
                        descriptionController.text,
                        selectedDate!,
                        selectedGroupId,
                        selectedSubtasks,
                      );
                      Navigator.of(outerContext).pop();
                    }
                  },
                  child: Text(saveButtonText),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      titleController.dispose();
      descriptionController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}