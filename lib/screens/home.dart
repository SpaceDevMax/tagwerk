import 'package:flutter/material.dart';
import '../services/export_to_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TodoService _todoService = TodoService();
  var selectedIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = TodoBuilder(
          todoBox: _todoService.todoBox,
          filter: (todo) {
            if (todo?['isDone'] == true) return false;
            final dueMs = todo?['dueDate'] as int?;
            if (dueMs == null) return false;
            final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
            final now = DateTime.now();
            return due.year == now.year && due.month == now.month && due.day == now.day;
          },
        );
      case 1:
        page = TodoBuilder(
          todoBox: _todoService.todoBox,
          filter: (todo) => todo?['isDone'] == true,
        );
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
                  destinations: const [
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
                  child: page,
              ),

            ]
          ),
          floatingActionButton: FloatingActionButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      DateTime? selectedDate;
                      return StatefulBuilder(
                        builder: (BuildContext dialogContext, StateSetter dialogSetState) {

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
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        String dateText;
                                        if (selectedDate == null) {
                                          dateText = 'No due date selected (required)';
                                        } else {
                                          dateText = 'Due: ${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
                                        }
                                        return Text(dateText);
                                      },
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final picked = await showDatePicker(
                                          context: dialogContext,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          dialogSetState(() => selectedDate = picked);
                                        }
                                      },
                                      child: const Text('Pick Date'),
                                    ),
                                  ],
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
                                  if (_textController.text.isNotEmpty && selectedDate != null) {
                                    final todoMap = {
                                      'title': _textController.text,
                                      'description': _descriptionController.text,
                                      'isDone': false,
                                      'dueDate': selectedDate!.millisecondsSinceEpoch,
                                    };
                                    _todoService.todoBox.add(todoMap);
                                    _textController.clear();
                                    _descriptionController.clear();
                                    Navigator.of(context).pop();
                                  }
                                },
                                child: const Text('Add'),
                              ),
                            ],
                          );
                        },
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

