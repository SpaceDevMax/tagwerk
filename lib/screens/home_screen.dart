// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';


import '../models/models.dart';
import '../services/todo_service.dart';
import '../widgets/task_dialog.dart';
import '../widgets/todo_builder.dart';
import 'overdue_screen.dart';

class HomeScreen extends StatefulWidget {
  final Isar isar;

  const HomeScreen({super.key, required this.isar});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late final TodoService _todoService;
  var selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _todoService = TodoService(widget.isar);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tagwerk'),
          ),
          body: Row(
            children: [
              SafeArea(
                child: StreamBuilder<List<Group>>(
                  stream: _todoService.groupsStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final groups = snapshot.data!;
                    final destinations = <NavigationRailDestination>[
                      const NavigationRailDestination(icon: Icon(Icons.home), label: Text('Today')),
                      const NavigationRailDestination(icon: Icon(Icons.warning), label: Text('Overdue')),
                      const NavigationRailDestination(icon: Icon(Icons.circle), label: Text('Open')),
                      const NavigationRailDestination(icon: Icon(Icons.check_box), label: Text('Done')),
                    ] + groups.map((group) => NavigationRailDestination(
                      icon: Icon(Icons.circle, color: Color(group.color)),
                      label: Text(group.name),
                    )).toList();

                    return NavigationRail(
                      extended: constraints.maxWidth >= 600,
                      destinations: destinations,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (value) {
                        setState(() {
                          selectedIndex = value;
                        });
                      },
                    );
                  },
                ),
              ),
              Expanded(
                child: _buildPage(selectedIndex),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              DateTime? preDue;
              int? preGroup;
              if (selectedIndex == 0) {
                preDue = DateTime.now();
              } else if (selectedIndex >= 4) {
                final groups = _todoService.getGroups();
                final groupIndex = selectedIndex - 4;
                preGroup = groups[groupIndex].id;
              }
              TaskDialog(
                todoService: _todoService,
                initialDueDate: preDue,
                initialGroupId: preGroup,
                onSave: (title, description, dueDate, groupId) {
                  _todoService.addTask(title, description, dueDate, groupId);
                },
              ).show(context);
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return TodoBuilder(
          todoService: _todoService,
          filter: (todo) {
            final dueMs = todo.dueDate;
            if (dueMs == null) return false;
            final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
            final now = DateTime.now();
            final isDueToday = due.year == now.year && due.month == now.month && due.day == now.day;
            if (!isDueToday) return false;

            final isDone = todo.isDone;
            if (!isDone) return true;  // Always include unfinished today tasks

            // Include done only if completed today
            final completedMs = todo.completedAt;
            if (completedMs == null) return false;
            final completed = DateTime.fromMillisecondsSinceEpoch(completedMs);
            return completed.year == now.year && completed.month == now.month && completed.day == now.day;
          },
          viewKey: 'today',
        );
      case 1:
        return OverdueScreen(todoService: _todoService);
      case 2:
        return TodoBuilder(
          todoService: _todoService,
          filter: (todo) => !todo.isDone,
          viewKey: 'open',
        );
      case 3:
        return TodoBuilder(
          todoService: _todoService,
          filter: (todo) => todo.isDone,
          viewKey: 'done',
        );
      default:
        final groupIndex = index - 4;
        final groups = _todoService.getGroups();
        final groupId = groups[groupIndex].id;
        return TodoBuilder(
          todoService: _todoService,
          filter: (todo) => todo.groupId == groupId,
          viewKey: 'group_$groupId',
        );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}