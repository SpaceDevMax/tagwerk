import 'package:flutter/material.dart';
import '../services/export_to_home_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tagwerk'),
          ),
          body: Row(
            children: [
              SafeArea(
                child: ValueListenableBuilder(
                  valueListenable: _todoService.groupBox.listenable(),
                  builder: (context, Box<Map> groupBox, _) {
                    final groups = _todoService.getGroups();
                    final destinations = <NavigationRailDestination>[
                      const NavigationRailDestination(icon: Icon(Icons.home), label: Text('Today')),
                      const NavigationRailDestination(icon: Icon(Icons.warning), label: Text('Overdue')),
                      const NavigationRailDestination(icon: Icon(Icons.circle), label: Text('Open')),
                      const NavigationRailDestination(icon: Icon(Icons.check_box), label: Text('Done')),
                    ] + groups.map((group) => NavigationRailDestination(
                      icon: Icon(Icons.circle, color: Color(group['color'] as int)),
                      label: Text(group['name'] as String),
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
                preGroup = selectedIndex - 4;
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
            final dueMs = todo?['dueDate'] as int?;
            if (dueMs == null) return false;
            final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
            final now = DateTime.now();
            final isDueToday = due.year == now.year && due.month == now.month && due.day == now.day;
            if (!isDueToday) return false;

            final isDone = todo?['isDone'] == true;
            if (!isDone) return true;  // Always include unfinished today tasks

            // Include done only if completed today
            final completedMs = todo?['completedAt'] as int?;
            if (completedMs == null) return false;  // Shouldn't happen, but safety
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
          filter: (todo) => todo?['isDone'] == false,
          viewKey: 'open',
        );

      case 3:
        return TodoBuilder(
          todoService: _todoService,
          filter: (todo) => todo?['isDone'] == true,
          viewKey: 'done',
        );

      default:
        final groupIndex = index - 4;
        return TodoBuilder(
          todoService: _todoService,
          filter: (todo) => todo?['groupId'] == groupIndex,
          viewKey: 'group_$groupIndex',
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