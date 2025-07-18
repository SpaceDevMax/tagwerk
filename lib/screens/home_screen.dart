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
        );
      case 1:
        page = TodoBuilder(
          todoService: _todoService,
          filter: (todo) => todo?['isDone'] == false,

          );
      case 2:
        page = TodoBuilder(
          todoService: _todoService,
          filter: (todo) => todo?['isDone'] == true,
          comparator: (a, b) => (b['completedAt'] as int? ?? 0).compareTo(a['completedAt'] as int? ?? 0),
        );
      case 3:
        page = EmptyScreen();
      default:
        throw UnimplementedError('no widget for $selectedIndex');   
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tagwerk'),
          ),
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >=600,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.home), label: Text('Today')),
                    NavigationRailDestination(icon: Icon(Icons.circle), label: Text('All')),
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
              TaskDialog(
                onSave: (title, description, dueDate) {
                  _todoService.addTask(title, description, dueDate);
                },
              ).show(context);
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

