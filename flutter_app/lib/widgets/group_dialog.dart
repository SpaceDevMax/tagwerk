// widgets/group_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../services/todo_service.dart';

class GroupDialog extends StatelessWidget {
  final TodoService todoService;
  final void Function(String name, Color color) onSave;
  final String dialogTitle;
  final String saveButtonText;

  const GroupDialog({
    super.key,
    required this.todoService,
    required this.onSave,
    this.dialogTitle = 'Create Group',
    this.saveButtonText = 'Create',
  });

  void show(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    Color selectedColor = Colors.blue;

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
                    controller: nameController,
                    decoration: const InputDecoration(hintText: 'Enter group name'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  ColorPicker(
                    pickerColor: selectedColor,
                    onColorChanged: (color) {
                      selectedColor = color;
                    },
                    showLabel: true,
                    pickerAreaHeightPercent: 0.8,
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
                    if (nameController.text.isNotEmpty) {
                      onSave(
                        nameController.text,
                        selectedColor,
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
      nameController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}