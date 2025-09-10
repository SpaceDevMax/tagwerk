// In main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tagwerk/screens/home_screen.dart';
import 'screens/auth_page.dart';
import 'services/todo_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final databasesPath = await getDatabasesPath();
  final path = join(databasesPath, 'tagwerk.db');
  final database = await openDatabase(path, version: 1, onCreate: _onCreate);

  final todoService = TodoService(database);
  await todoService.init();

  runApp(MyApp(database: database, todoService: todoService));
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE todos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      is_done INTEGER NOT NULL,
      due_date INTEGER,
      completed_at INTEGER,
      group_id INTEGER,
      order_ INTEGER NOT NULL,
      subtasks TEXT NOT NULL,
      saved_due_date INTEGER,
      created_at INTEGER NOT NULL,
      user_id TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE groups (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      color INTEGER NOT NULL,
      user_id TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE settings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      key TEXT NOT NULL UNIQUE,
      value TEXT,
      user_id TEXT NOT NULL
    )
  ''');
}

class MyApp extends StatelessWidget {
  final Database database;
  final TodoService todoService;

  const MyApp({super.key, required this.database, required this.todoService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tagwerk',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: todoService.isLoggedIn() ? HomeScreen(database: database) : AuthPage(database: database),
    );
  }
}