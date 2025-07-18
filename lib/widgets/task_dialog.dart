import 'package:flutter/material.dart';

import '../services/todo_service.dart';
import '../widgets/group_dialog.dart';
 

class TaskDialog extends StatelessWidget {
  final TodoService todoService;
  final String? initialTitle;
  final String? initialDescription;
  final DateTime? initialDueDate;
  final int? initialGroupId;
  final void Function(String title, String description, DateTime dueDate, int? groupId) onSave;
  final String dialogTitle;
  final String saveButtonText;

  const TaskDialog({
    super.key,
    required this.todoService,
    this.initialTitle,
    this.initialDescription,
    this.initialDueDate,
    this.initialGroupId,
    required this.onSave,
    this.dialogTitle = 'Add Task',
    this.saveButtonText = 'Add',
  });

  void show(BuildContext context) {
    final TextEditingController titleController = TextEditingController(text: initialTitle ?? '');
    final TextEditingController descriptionController = TextEditingController(text: initialDescription ?? '');
    DateTime? selectedDate = initialDueDate;
    int? selectedGroupId = initialGroupId;

    showDialog(
      context: context,
      builder: (BuildContext outerContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter dialogSetState) {
            return AlertDialog(
              title: Text(dialogTitle),
              content: Column(
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
                            initialDate: selectedDate ?? DateTime.now(),
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
                  DropdownButton<int?>(
                    value: selectedGroupId,
                    hint: const Text('Select Group'),
                    items: todoService.getGroups().asMap().entries.map((entry) {
                      int idx = entry.key;
                      Map<String, dynamic> group = entry.value;
                      return DropdownMenuItem<int?>(
                        value: idx,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              color: Color(group['color'] as int),
                            ),
                            const SizedBox(width: 8),
                            Text(group['name'] as String),
                          ],
                        ),
                      );
                    }).toList()
                      ..add(const DropdownMenuItem<int?>(value: null, child: Text('No Group')))
                      ..add(const DropdownMenuItem<int?>(value: -1, child: Text('Create New Group'))),
                    onChanged: (value) {
                      if (value == -1) {
                        GroupDialog(
                          todoService: todoService,
                          onSave:(name, color) {
                            todoService.addGroup(name, color);
                            dialogSetState((){
                              selectedGroupId = todoService.groupBox.length - 1;
                            });
                          },
                        ).show(dialogContext);
                      } else {
                      dialogSetState(() => selectedGroupId = value);
                      }
                    },
                  ),
                ],
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
    // This widget is meant to be used via its show() method, not built directly
    return const SizedBox.shrink();
  }
}