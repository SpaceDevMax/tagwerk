import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';



class TodoBuilder extends StatelessWidget {
  const TodoBuilder({
    super.key,
    required this.todoBox,
    this.filter,
  });

  final Box<Map> todoBox;
  final bool Function(Map? todo)? filter;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: todoBox.listenable(),
      builder: (context, Box<Map> box, _) {
        List<int> filteredIndices = [];
        for (int i = 0; i < box.length; i++) {
          final todo = box.getAt(i);
          if (filter == null ? filter!(todo) : true) {
            filteredIndices.add(i);
          }
        }

        return filteredIndices.isEmpty
            ? const Center(child: Text('No tasks yet. Add one!'))
            : ListView.builder(
                itemCount: filteredIndices.length,
                itemBuilder: (context, idx) {
                  final int realIndex = filteredIndices[idx];
                  final todo = box.getAt(realIndex);
                  String dueStr = '';
                  final dueMs = todo?['dueDate'] as int?;
                  if (dueMs != null) {
                    final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
                    dueStr = ' - Due: ${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
                  }

                  return ListTile(
                    title: Text(
                      todo?['title'] ?? '',
                      style: TextStyle(
                        decoration: todo?['isDone'] == true ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      (todo?['description'] ?? '') + dueStr,
                      style: TextStyle(
                        decoration: todo?['isDone'] == true ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    leading: Checkbox(
                      value: todo?['isDone'] ?? false,
                      onChanged: (value) {
                        final updatedTodo = Map<String, dynamic>.from(todo ?? {});
                        updatedTodo['isDone'] = value ?? false;
                        box.putAt(realIndex, updatedTodo);
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        box.deleteAt(realIndex);
                      },
                    ),
                  );
                },
              );
      },
    );
  }
}
