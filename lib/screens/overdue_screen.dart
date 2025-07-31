import 'package:flutter/material.dart';
import '../services/todo_service.dart';
import '../widgets/todo_builder.dart';

class OverdueScreen extends StatelessWidget {
  final TodoService todoService;

  const OverdueScreen({super.key, required this.todoService});

  @override
  Widget build(BuildContext context) {
    return TodoBuilder(
      todoService: todoService,
      filter: (todo) {
        final dueMs = todo?['dueDate'] as int?;
        if (dueMs == null) return false;
        final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
        final today = DateTime.now();
        return !todo?['isDone'] && due.isBefore(DateTime(today.year, today.month, today.day));
      },
      viewKey: 'overdue',
    );
  }
}