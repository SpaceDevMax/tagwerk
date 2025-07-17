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
      };
      _todoBox.add(todoMap);
    }
  }

  // Add more methods here later, e.g., for delete or update if needed
}