import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/todo_service.dart';
import '../widgets/task_tile.dart'; // Added import

class TodoBuilder extends StatefulWidget {
  const TodoBuilder({
    super.key,
    required this.todoService,
    this.filter,
    required this.viewKey,
  });

  final TodoService todoService;
  final bool Function(Map? todo)? filter;
  final String viewKey;

  @override
  State<TodoBuilder> createState() => _TodoBuilderState();
}

class _TodoBuilderState extends State<TodoBuilder> {
  late String _sortOption;

  @override
  void initState() {
    super.initState();
    _sortOption = widget.todoService.settingsBox.get('${widget.viewKey}_sort') ?? 'due_asc';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.todoService.todoBox.listenable(),
      builder: (context, Box<Map> box, _) {
        List<int> filteredIndices = [];
        for (int i = 0; i < box.length; i++) {
          final todo = box.getAt(i);
          bool include = true;
          if (widget.filter != null) {
            include = widget.filter!(todo);
          }
          if (include) {
            filteredIndices.add(i);
          }
        }

        if (filteredIndices.isNotEmpty) {
          filteredIndices.sort((aIdx, bIdx) {
            final a = box.getAt(aIdx)!;
            final b = box.getAt(bIdx)!;
            if (_sortOption == 'custom') {
              final aOrder = a['order'] as double? ?? 0.0;
              final bOrder = b['order'] as double? ?? 0.0;
              return aOrder.compareTo(bOrder);
            }
            switch (_sortOption) {
              case 'created_desc':
                return int.parse(b['id'] as String).compareTo(int.parse(a['id'] as String));
              case 'created_asc':
                return int.parse(a['id'] as String).compareTo(int.parse(b['id'] as String));
              case 'due_asc':
                final large = 9223372036854775807;
                final aDue = a['dueDate'] as int? ?? large;
                final bDue = b['dueDate'] as int? ?? large;
                return aDue.compareTo(bDue);
              default:
                return 0;
            }
          });
        }

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
                      widget.todoService.settingsBox.put('${widget.viewKey}_sort', _sortOption);
                      widget.todoService.settingsBox.flush();
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
              child: filteredIndices.isEmpty
                  ? const Center(child: Text('No tasks yet. Add one!'))
                  : (_sortOption == 'custom'
                      ? ReorderableListView.builder(
                          itemCount: filteredIndices.length,
                          onReorder: (int oldIndex, int newIndex) {
                            final int originalNewIndex = newIndex;
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final int realOld = filteredIndices[oldIndex];
                            final todo = box.getAt(realOld);
                            final updatedTodo = Map<String, dynamic>.from(todo ?? {});
                            double newOrder;
                            if (originalNewIndex == filteredIndices.length) {
                              final lastReal = filteredIndices[filteredIndices.length - 1];
                              final lastOrder = box.getAt(lastReal)!['order'] as double? ?? 0.0;
                              newOrder = lastOrder + 1;
                            } else if (newIndex == 0) {
                              final firstReal = filteredIndices[0];
                              final firstOrder = box.getAt(firstReal)!['order'] as double? ?? 0.0;
                              newOrder = firstOrder - 1;
                            } else {
                              final prevReal = filteredIndices[newIndex - 1];
                              final nextReal = filteredIndices[newIndex];
                              final prevOrder = box.getAt(prevReal)!['order'] as double? ?? 0.0;
                              final nextOrder = box.getAt(nextReal)!['order'] as double? ?? 0.0;
                              newOrder = (prevOrder + nextOrder) / 2;
                            }
                            updatedTodo['order'] = newOrder;
                            box.putAt(realOld, updatedTodo);
                          },
                          itemBuilder: (context, idx) {
                            final int realIndex = filteredIndices[idx];
                            final todo = box.getAt(realIndex)!;
                            return TaskTile(
                              key: ValueKey(todo['id']),
                              todoService: widget.todoService,
                              box: box,
                              realIndex: realIndex,
                              todo: todo.cast<String, dynamic>(),
                              showDragHandle: true,
                            );
                          },
                        )
                      : ListView.builder(
                          itemCount: filteredIndices.length,
                          itemBuilder: (context, idx) {
                            final int realIndex = filteredIndices[idx];
                            final todo = box.getAt(realIndex)!;
                            return TaskTile(
                              key: ValueKey(todo['id']),
                              todoService: widget.todoService,
                              box: box,
                              realIndex: realIndex,
                              todo: todo.cast<String, dynamic>(),
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