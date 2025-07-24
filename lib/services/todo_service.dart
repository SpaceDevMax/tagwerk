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
    _migrateTodos();  // Add this call to run migration on init
  }

  Box<Map> get todoBox => _todoBox;
  Box<Map> get groupBox => _groupBox;

  void _migrateTodos() {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < _todoBox.length; i++) {
      final todo = _todoBox.getAt(i);
      if (todo != null) {
        final updatedTodo = Map<String, dynamic>.from(todo);
        bool changed = false;
        if (updatedTodo['id'] == null) {
          updatedTodo['id'] = '$now$i';  // Unique ID based on timestamp + index
          changed = true;
        }
        if (updatedTodo['order'] == null) {
          updatedTodo['order'] = now.toDouble() + i;  // Set order based on current position/timestamp
          changed = true;
        }
        if (changed) {
          _todoBox.putAt(i, updatedTodo);
        }
        if (updatedTodo['savedDueDate'] == null) {
          // No need to set, defaults to null
        }
      }
    }
  }

  void addTask(String title, String description, DateTime dueDate, [int? groupId]) {
    if (title.isNotEmpty) {
      final todoMap = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(), // Unique ID
        'title': title,
        'description': description,
        'isDone': false,
        'dueDate': dueDate.millisecondsSinceEpoch,
        'completedAt': null,
        'groupId': groupId,
        'order': DateTime.now().millisecondsSinceEpoch.toDouble(),  // Add this line for sortable order
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

void toggleDueToday(int index) {
  final current = _todoBox.getAt(index);
  if (current != null) {
    final updated = Map<String, dynamic>.from(current);
    final dueMs = updated['dueDate'] as int?;
    final savedMs = updated['savedDueDate'] as int?;
    final now = DateTime.now();
    final todayMs = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    bool isDueToday = false;
    if (dueMs != null) {
      final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
      isDueToday = due.year == now.year && due.month == now.month && due.day == now.day;
    }
    if (!isDueToday) {
      updated['savedDueDate'] = dueMs;  // Save old due (null if none)
      updated['dueDate'] = todayMs;
    } else {
      if (savedMs != null) {
        updated['dueDate'] = savedMs;
      } else {
        updated['dueDate'] = null;  // For original today tasks, remove due date
      }
      updated.remove('savedDueDate');
    }
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