// Manage adding, editing and deleting tasks


import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TodoService {
  late Box<Map> _todoBox;

  TodoService() {
    _todoBox = Hive.box<Map>('todos');
  }

  Box<Map> get todoBox => _todoBox;

  void addTask(String title, String description, DateTime dueDate) {
    if (title.isNotEmpty) {
      final todoMap = {
        'title': title,
        'description': description,
        'isDone': false,
        'dueDate': dueDate.millisecondsSinceEpoch,
        'completedAt': null,
      };
      _todoBox.add(todoMap);
    }
  }

  void editTask(int index, String title, String description, DateTime dueDate) {
  final current = _todoBox.getAt(index);
  if (current != null) {
    final updated = Map<String, dynamic>.from(current);
    updated['title'] = title;
    updated['description'] = description;
    updated['dueDate'] = dueDate.millisecondsSinceEpoch;
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

  // Add more methods here later, e.g., for delete or update if needed
}