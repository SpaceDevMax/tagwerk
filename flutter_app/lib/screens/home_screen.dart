import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../services/todo_service.dart';
import '../widgets/task_dialog.dart';
import '../widgets/todo_builder.dart';
import 'overdue_screen.dart';
import 'auth_page.dart';

class HomeScreen extends StatefulWidget {
  final Database database;

  const HomeScreen({super.key, required this.database});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late final TodoService _todoService;
  var selectedIndex = 0;
  bool _isConnected = false; // Track server connection
  bool _isSynced = true; // Track sync status
  Timer? _connectionTimer; //Store timer for cancellation

  @override
  void initState() {
    super.initState();
    _todoService = TodoService(widget.database);
    _todoService.startSync();
    _checkConnection(); // Initial check
    Timer.periodic(const Duration(seconds: 5), (_) => _checkConnection()); // Periodic check
  }

  Future<void> _checkConnection() async {
    try {
      final response = await http.get(Uri.parse('${_todoService.serverUrl}/todos')).timeout(const Duration(seconds: 2));
      if (mounted) { // Check if widget is still mounted
        setState(() {
        _isConnected = response.statusCode == 200;
        _isSynced = true; // Assume synced if server reachable; refine with last sync time if needed
  });
}
    } catch (e) {
      if (mounted) { // Check if widget is still mounted
        setState(() {
          _isConnected = false;
          _isSynced = false; // Not synced if server unreachable
        });
      }
    }
  }

  @override
  void dispose() {
    _connectionTimer?.cancel(); // Cancel timer
    _textController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tagwerk'),
            actions: [
              IconButton(
                onPressed: () async {
                  await _todoService.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => AuthPage(database: widget.database)),
                    );
                  }
                },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: Stack(
            children: [
              Row(
                children: [
                  SafeArea(
                    child: StreamBuilder<List<Group>>(
                      stream: _todoService.groupsStream,
                      builder: (context, snapshot) {
                        final groups = snapshot.data ?? [];
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
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
              Positioned(
                left: 8,
                bottom: 8,
                child: Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.cloud : Icons.cloud_off,
                      color: _isConnected ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isSynced ? Icons.sync : Icons.sync_problem,
                      color: _isSynced ? Colors.green : Colors.yellow,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              DateTime? preDue;
              int? preGroup;
              if (selectedIndex == 0) {
                preDue = DateTime.now();
              } else if (selectedIndex >= 4) {
                final groups = await _todoService.getGroups();
                final groupIndex = selectedIndex - 4;
                preGroup = groups[groupIndex].id;
              }
              TaskDialog(
                todoService: _todoService,
                initialDueDate: preDue,
                initialGroupId: preGroup,
                onSave: (title, description, dueDate, groupId, subtasks) {
                  _todoService.addTask(title, description, dueDate, subtasks, groupId);
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
            if (!isDone) return true;

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
            return FutureBuilder<List<Group>>(
              future: _todoService.getGroups(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final groups = snapshot.data!;
                final groupIndex = index - 4;
                final groupId = groups[groupIndex].id;
                return TodoBuilder(
                  todoService: _todoService,
                  filter: (todo) => todo.groupId == groupId,
                  viewKey: 'group_$groupId',
                );
              },
            );
    }
  }

}