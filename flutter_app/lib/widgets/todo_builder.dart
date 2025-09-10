// In flutter_app/lib/widgets/todo_builder.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/todo_service.dart';
import 'task_tile.dart';

class TodoBuilder extends StatefulWidget {
  const TodoBuilder({
    super.key,
    required this.todoService,
    this.filter,
    required this.viewKey,
  });

  final TodoService todoService;
  final bool Function(Todo)? filter;
  final String viewKey;

  @override
  State<TodoBuilder> createState() => _TodoBuilderState();
}

class _TodoBuilderState extends State<TodoBuilder> {
  String _sortOption = 'due_asc';

  @override
  void initState() {
    super.initState();
    _initSortOption();
  }

  Future<void> _initSortOption() async {
    final sortOption = await widget.todoService.getSetting('${widget.viewKey}_sort');
    setState(() {
      _sortOption = sortOption ?? 'due_asc';
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Todo>>(
      stream: widget.todoService.getFilteredTodosStream(widget.filter, _sortOption),
      builder: (context, snapshot) {
        final todos = snapshot.data ?? [];
        print('StreamBuilder todos: ${todos.length}'); // Debug
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DropdownButton<String>(
                  value: _sortOption,
                  onChanged: (newValue) async {
                    setState(() {
                      _sortOption = newValue!;
                    });
                    await widget.todoService.setSetting('${widget.viewKey}_sort', _sortOption);
                  },
                  items: const [
                    DropdownMenuItem(value: 'custom', child: Text('Custom')),
                    DropdownMenuItem(value: 'created_desc', child: Text('Oldest to Latest')),
                    DropdownMenuItem(value: 'created_asc', child: Text('Latest to Oldest')),
                    DropdownMenuItem(value: 'due_asc', child: Text('Due Next to Due Last')),
                  ],
                ),
              ],
            ),
            Expanded(
              child: todos.isEmpty
                  ? const Center(child: Text('No tasks yet. Add one!'))
                  : (_sortOption == 'custom'
                      ? ReorderableListView.builder(
                          itemCount: todos.length,
                          onReorder: (int oldIndex, int newIndex) async {
                            final originalNewIndex = newIndex;
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final todo = todos[oldIndex];
                            int newOrder;
                            if (originalNewIndex == todos.length) {
                              newOrder = todos.last.order + 1;
                            } else if (newIndex == 0) {
                              newOrder = todos[0].order - 1;
                            } else {
                              final prevOrder = todos[newIndex - 1].order;
                              final nextOrder = todos[newIndex].order;
                              newOrder = (prevOrder + nextOrder) ~/ 2;
                            }
                            todo.order = newOrder;
                            await widget.todoService.database.update('todos', todo.toJson(), where: 'id = ?', whereArgs: [todo.id]);
                          },
                          itemBuilder: (context, idx) {
                            final todo = todos[idx];
                            return TaskTile(
                              key: ValueKey(todo.id),
                              todoService: widget.todoService,
                              todoId: todo.id!,
                              todo: todo,
                              showDragHandle: true,
                            );
                          },
                        )
                      : ListView.builder(
                          itemCount: todos.length,
                          itemBuilder: (context, idx) {
                            final todo = todos[idx];
                            return TaskTile(
                              key: ValueKey(todo.id),
                              todoService: widget.todoService,
                              todoId: todo.id!,
                              todo: todo,
                              showDragHandle: false,
                            );
                          },
                        )),
            ),
          ],
        );
      },
    );
  }
}