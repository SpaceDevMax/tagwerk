// Hive logic
//Manage adding, editing and deleting tasks


import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TodoService {
  late Box<Map> _todoBox;
  late Box<Map> _groupBox;

  TodoService() {
    _todoBox = Hive.box<Map>('todos');
    _groupBox = Hive.box<Map>('groups');
  }

  Box<Map> get todoBox => _todoBox;
  Box<Map> get groupBox => _groupBox;

  void addTask(String title, String description, DateTime dueDate, [int? groupId]) {
    if (title.isNotEmpty) {
      final todoMap = {
        'title': title,
        'description': description,
        'isDone': false,
        'dueDate': dueDate.millisecondsSinceEpoch,
        'completedAt': null,
        'groupId': groupId,
      };
      _todoBox.add(todoMap);
    }
  }

  void editTask(int index, String title, String description, DateTime dueDate, [int? groupId]) {
  final current = _todoBox.getAt(index);
  if (current != null) {
    final updated = Map<String, dynamic>.from(current);
    updated['title'] = title;
    updated['description'] = description;
    updated['dueDate'] = dueDate.millisecondsSinceEpoch;
    if (groupId != null) {
      updated['groupId'] = groupId;
    }
    // Preserve isDone
    _todoBox.putAt(index, updated);
  }
}

void deleteTask(int index) {
  _todoBox.deleteAt(index);
}

void updateIsDone(int index, bool isDone) {
  final current = _todoBox.getAt(index);
  if (current != null) {
    final updated = Map<String, dynamic>.from(current);
    if (isDone && !(updated['isDone'] ?? false)) {
      // Set completedAt only when newly marking as done
      updated['completedAt'] = DateTime.now().millisecondsSinceEpoch;
    } else if (!isDone) {
      // Clear completedAt when unmarking
      updated['completedAt'] = null;
    }
    updated['isDone'] = isDone;
    _todoBox.putAt(index, updated);
  }
}

void addGroup(String name, Color color) {
    groupBox.add({'name': name, 'color': color.value});
  }

  // Method to get all groups as list of maps
  List<Map<String, dynamic>> getGroups() {
    return _groupBox.values.map((map) => map.cast<String, dynamic>()).toList();  
    }

  // Method to edit a group (by index)
  void editGroup(int index, String name, Color color) {
    final updatedGroup = Map<String, dynamic>.from(groupBox.getAt(index) ?? {});
    updatedGroup['name'] = name;
    updatedGroup['color'] = color.value;
    groupBox.putAt(index, updatedGroup);
  }

  // Method to delete a group (and unassign tasks from it)
  void deleteGroup(int index) {
    final groupId = index;  // Assuming index is the key
    // Unassign tasks belonging to this group
    for (int i = 0; i < todoBox.length; i++) {
      final todo = todoBox.getAt(i);
      if (todo?['groupId'] == groupId) {
        final updatedTodo = Map<String, dynamic>.from(todo ?? {});
        updatedTodo.remove('groupId');
        todoBox.putAt(i, updatedTodo);
      }
    }
    groupBox.deleteAt(index);
  }

  // Add more methods here later, e.g., for delete or update if needed
}