import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'empty_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late Box<Map> _todoBox;
  var selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _todoBox = Hive.box<Map>('todos');
  }

  void _addTask() {
    if (_textController.text.isNotEmpty) {
      final todoMap = {
        'title': _textController.text,
        'description': _descriptionController.text,
        'isDone': false,
      };
      _todoBox.add(todoMap);
      //for (var i = 0; i < _todoBox.length; i++) {
        //print('Todo #$i: ${_todoBox.getAt(i)}');
      //}
      _textController.clear();
      _descriptionController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = TodoBuilder(todoBox: _todoBox);
      case 1:
        page = TodoBuilder(todoBox: _todoBox);
      case 2:
        page = EmptyScreen();
      default:
        throw UnimplementedError('no widget for $selectedIndex');   
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('TODO App'),
          ),
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >=600,
                  destinations: [
                    NavigationRailDestination(icon: Icon(Icons.home), label: Text('Home')),
                    NavigationRailDestination(icon: Icon(Icons.check_box), label: Text('Done')),
                    NavigationRailDestination(icon: Icon(Icons.circle), label: Text('Empty')),

                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  }

                )
              ),
              Expanded(
                  child:
                    page,
              ),

            ]
          ),
          floatingActionButton: FloatingActionButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Add Task'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _textController,
                              decoration: const InputDecoration(hintText: 'Enter task title'),
                              autofocus: true,
                            ),
                            TextField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(hintText: 'Enter description'),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
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
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class TodoBuilder extends StatelessWidget {
  const TodoBuilder({
    super.key,
    required Box<Map> todoBox,
  }) : _todoBox = todoBox;

  final Box<Map> _todoBox;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _todoBox.listenable(),
      builder: (context, Box<Map> box, _) {
        return box.isEmpty
            ? const Center(child: Text('No tasks yet. Add one!'))
            : ListView.builder(
                itemCount: box.length,
                itemBuilder: (context, index) {
                  final todo = box.getAt(index);
                  return ListTile(
                    title: Text(
                      todo?['title'] ?? '',
                      style: TextStyle(
                        decoration: todo?['isDone'] == true ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      todo?['description'] ?? '',
                      style: TextStyle(
                        decoration: todo?['isDone'] == true ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    leading: Checkbox(
                      value: todo?['isDone'] ?? false,
                      onChanged: (value) {
                        final updatedTodo = Map<String, dynamic>.from(todo ?? {});
                        updatedTodo['isDone'] = value ?? false;
                        box.putAt(index, updatedTodo);
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        box.deleteAt(index);
                      },
                    ),
                  );
                },
              );
      },
                    );
  }
}