import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';


import 'task.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Task> _tasks = [];
  final TextEditingController _textController = TextEditingController();
  void _addTask() async {
      final taskTitle = _textController.text;
    if (_textController.text.isNotEmpty) {
      setState(() {
        _tasks.add(Task(_textController.text));
      });
      final todoBox = await Hive.openBox<Map>('todos');
      final todoMap = {
        'title': taskTitle,
        'description': 'Description',
      };
      todoBox.add(todoMap);
      for (var i = 0; i < todoBox.length; i++) {
        print('Todo #$i: ${todoBox.getAt(i)}');
      }
      _textController.clear();
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TODO App'),
      ),
      body: _tasks.isEmpty
          ? const Center(child: Text('No tasks yet. Add one!'))
          : ValueListenableBuilder(
            valueListenable: Hive.box<Map>('todos').listenable(),
            builder: (context, Box<Map> box, _) {
              return ListView.builder(
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final todo = box.getAt(index);
                    final task = _tasks[index];
                    return ListTile(
                      title: Text(
                        task.title,
                        style: TextStyle(
                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      //subtitle: Text(todo?['description'] ?? ''),
                      leading: Checkbox(
                        value: task.isDone,
                        onChanged: (value) {
                          setState(() {
                            task.isDone = value!;
                          });
                        },
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _tasks.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                );
            }
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Add Task'),
                content: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(hintText: 'Enter task title'),
                  autofocus: true,
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      _addTask();
                      Navigator.of(context).pop();

                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}