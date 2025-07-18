import 'package:flutter/material.dart';

class TaskDialog extends StatelessWidget {
  final String? initialTitle;
  final String? initialDescription;
  final DateTime? initialDueDate;
  final void Function(String title, String description, DateTime dueDate) onSave;
  final String dialogTitle;
  final String saveButtonText;

  const TaskDialog({
    super.key,
    this.initialTitle,
    this.initialDescription,
    this.initialDueDate,
    required this.onSave,
    this.dialogTitle = 'Add Task',
    this.saveButtonText = 'Add',
  });

  void show(BuildContext context) {
    final TextEditingController titleController = TextEditingController(text: initialTitle ?? '');
    final TextEditingController descriptionController = TextEditingController(text: initialDescription ?? '');
    DateTime? selectedDate = initialDueDate;

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