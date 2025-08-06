// main.dart
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tagwerk/screens/home_screen.dart';

import './models/models.dart';
import 'screens/auth_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [TodoSchema, GroupSchema, SettingSchema],
    directory: dir.path,
  );

  Supabase.initialize(
    url: 'https://ohctttfsvqzxrimwolli.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9oY3R0dGZzdnF6eHJpbXdvbGxpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQyMDI1MDMsImV4cCI6MjA2OTc3ODUwM30.Fa-22ARF_Oe9TClRbJzdxQjkTSYKUsWTFKfwJbzEq5I',
  );

  runApp(MyApp(isar: isar));
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  final Isar isar;

  const MyApp({super.key, required this.isar});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tagwerk',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: supabase.auth.currentSession != null
          ? HomeScreen(isar: isar)
          : AuthPage(isar: isar),
    );
  }
}