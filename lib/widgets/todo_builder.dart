// widgets/todo_builder.dart
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
  late String _sortOption;

  @override
  void initState() {
    super.initState();
    _sortOption = widget.todoService.getSetting('${widget.viewKey}_sort') ?? 'due_asc';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Todo>>(
      stream: widget.todoService.getFilteredTodosStream(widget.filter, _sortOption),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final todos = snapshot.data!;
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DropdownButton<String>(
                  value: _sortOption,
                  onChanged: (newValue) {
                    setState(() {
                      _sortOption = newValue!;
                      widget.todoService.setSetting('${widget.viewKey}_sort', _sortOption);
                    });
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
                          onReorder: (int oldIndex, int newIndex) {
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
                            widget.todoService.isar.writeTxnSync(() {
                              todo.order = newOrder;
                              widget.todoService.isar.todos.putSync(todo);
                            });
                          },
                          itemBuilder: (context, idx) {
                            final todo = todos[idx];
                            return TaskTile(
                              key: ValueKey(todo.id),
                              todoService: widget.todoService,
                              todoId: todo.id,
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
                              todoId: todo.id,
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