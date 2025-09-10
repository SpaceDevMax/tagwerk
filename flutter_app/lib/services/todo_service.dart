import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';

class TodoService {
  final Database database;
  final String serverUrl = 'http://raspberrypi.local:8080'; // Replace with your Pi IP
  String? _authToken;
  bool _isSynced = true; // Track sync status
  Function(bool)? onSyncStatusChanged; // Callback for HomeScreen

  TodoService(this.database);

  bool get isSynced => _isSynced;

  bool isLoggedIn() {
    return _authToken != null;
  }

  Future<void> signUp(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) {
        _authToken = jsonDecode(response.body)['token'];
      } else {
        throw Exception('Sign up failed: ${response.body}');
      }
    } catch (e) {
      print('Signup error: $e');
      throw Exception('Cannot connect to server. Please check your network or server status.');
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/auth/signin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) {
        _authToken = jsonDecode(response.body)['token'];
      } else {
        throw Exception('Sign in failed: ${response.body}');
      }
    } catch (e) {
      print('Signin error: $e');
      throw Exception('Cannot connect to server. Please check your network or server status.');
    }
  }

  Future<void> signOut() async {
    _authToken = null;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  Stream<List<Group>> get groupsStream => Stream.periodic(const Duration(seconds: 1)).asyncMap((_) => getGroups());

  Future<void> startSync() async {
    await _pullFromServer();
    Timer.periodic(const Duration(seconds: 5), (_) => _syncToServer());
  }

  Future<void> _syncToServer() async {
    try {
      final todos = await getAllTodos();
      await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode(todos.map((t) => t.toJson()).toList()));
      final groups = await getGroups();
      await http.post(Uri.parse('$serverUrl/groups'), headers: _headers, body: jsonEncode(groups.map((g) => g.toJson()).toList()));
      final settings = await getAllSettings();
      await http.post(Uri.parse('$serverUrl/settings'), headers: _headers, body: jsonEncode(settings.map((s) => s.toJson()).toList()));
      _isSynced = true;
      onSyncStatusChanged?.call(true);
    } catch (e) {
      print('Sync to server failed: $e');
      _isSynced = false;
      onSyncStatusChanged?.call(false);
    }
  }

  Future<void> _pullFromServer() async {
    await _pullTodos();
    await _pullGroups();
    await _pullSettings();
  }

  Future<void> _pullTodos() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/todos'), headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final remoteTodos = (body is List ? body : []).map((json) => Todo.fromJson(json as Map<String, dynamic>)).toList();
        await database.transaction((txn) async {
          for (var todo in remoteTodos) {
            await txn.insert('todos', todo.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });
      }
    } catch (e) {
      print('Failed to sync todos: $e');
    }
  }

  Future<void> _pullGroups() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/groups'), headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final remoteGroups = (body is List ? body : []).map((json) => Group.fromJson(json as Map<String, dynamic>)).toList();
        await database.transaction((txn) async {
          for (var group in remoteGroups) {
            await txn.insert('groups', group.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });
      }
    } catch (e) {
      print('Failed to sync groups: $e');
    }
  }

  Future<void> _pullSettings() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/settings'), headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final remoteSettings = (body is List ? body : []).map((json) => Setting.fromJson(json as Map<String, dynamic>)).toList();
        await database.transaction((txn) async {
          for (var setting in remoteSettings) {
            await txn.insert('settings', setting.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });
      }
    } catch (e) {
      print('Failed to sync settings: $e');
    }
  }

  Future<void> addTask(String title, String description, DateTime dueDate, List<Subtask> subtasks, [int? groupId]) async {
    if (title.isEmpty) return;
    final userId = await getUserId();
    final todo = Todo(
      title: title,
      description: description,
      isDone: false,
      dueDate: dueDate.millisecondsSinceEpoch,
      groupId: groupId,
      order: DateTime.now().millisecondsSinceEpoch,
      subtasks: subtasks,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      userId: userId,
    );
    final id = await database.insert('todos', todo.toJson());
    todo.id = id;
    try {
      await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
      _isSynced = true;
      onSyncStatusChanged?.call(true);
    } catch (e) {
      print('Failed to sync addTask: $e');
      _isSynced = false;
      onSyncStatusChanged?.call(false);
    }
  }

  Future<String> getUserId() async {
    return 'local-user'; // Placeholder; implement properly for multi-user
  }

  Future<void> addSubtask(int todoId, String subTitle) async {
    if (subTitle.isEmpty) return;
    final todo = await getTodoById(todoId);
    if (todo != null) {
      todo.subtasks.add(Subtask(title: subTitle));
      await database.update('todos', todo.toJson(), where: 'id = ?', whereArgs: [todoId]);
      try {
        await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
        _isSynced = true;
        onSyncStatusChanged?.call(true);
      } catch (e) {
        print('Failed to sync addSubtask: $e');
        _isSynced = false;
        onSyncStatusChanged?.call(false);
      }
    }
  }

  Future<void> toggleSubtask(int todoId, int subIndex, bool isDone) async {
    final todo = await getTodoById(todoId);
    if (todo != null && subIndex < todo.subtasks.length) {
      todo.subtasks[subIndex].isDone = isDone;
      await database.update('todos', todo.toJson(), where: 'id = ?', whereArgs: [todoId]);
      try {
        await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
        _isSynced = true;
        onSyncStatusChanged?.call(true);
      } catch (e) {
        print('Failed to sync toggleSubtask: $e');
        _isSynced = false;
        onSyncStatusChanged?.call(false);
      }
    }
  }

  Future<bool> areAllSubtasksDone(int todoId) async {
    final todo = await getTodoByIdSync(todoId);
    return todo != null && todo.subtasks.isNotEmpty && todo.subtasks.every((sub) => sub.isDone);
  }

  Future<void> markAllSubtasksDone(int todoId) async {
    final todo = await getTodoById(todoId);
    if (todo != null) {
      for (var sub in todo.subtasks) {
        sub.isDone = true;
      }
      await database.update('todos', todo.toJson(), where: 'id = ?', whereArgs: [todoId]);
      try {
        await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
        _isSynced = true;
        onSyncStatusChanged?.call(true);
      } catch (e) {
        print('Failed to sync markAllSubtasksDone: $e');
        _isSynced = false;
        onSyncStatusChanged?.call(false);
      }
    }
  }

  Future<void> editTask(int todoId, String title, String description, DateTime dueDate, List<Subtask> subtasks, [int? groupId]) async {
    final todo = await getTodoById(todoId);
    if (todo != null) {
      todo.title = title;
      todo.description = description;
      todo.dueDate = dueDate.millisecondsSinceEpoch;
      todo.groupId = groupId ?? todo.groupId;
      todo.subtasks = subtasks;
      await database.update('todos', todo.toJson(), where: 'id = ?', whereArgs: [todoId]);
      try {
        await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
        _isSynced = true;
        onSyncStatusChanged?.call(true);
      } catch (e) {
        print('Failed to sync editTask: $e');
        _isSynced = false;
        onSyncStatusChanged?.call(false);
      }
    }
  }

  Future<void> deleteTask(int todoId) async {
    await database.delete('todos', where: 'id = ?', whereArgs: [todoId]);
    try {
      await http.delete(Uri.parse('$serverUrl/todos/$todoId'), headers: _headers);
      _isSynced = true;
      onSyncStatusChanged?.call(true);
    } catch (e) {
      print('Failed to sync deleteTask: $e');
      _isSynced = false;
      onSyncStatusChanged?.call(false);
    }
  }

  Future<void> updateIsDone(int todoId, bool isDone) async {
    final todo = await getTodoById(todoId);
    if (todo != null) {
      todo.isDone = isDone;
      todo.completedAt = isDone ? DateTime.now().millisecondsSinceEpoch : null;
      await database.update('todos', todo.toJson(), where: 'id = ?', whereArgs: [todoId]);
      try {
        await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
        _isSynced = true;
        onSyncStatusChanged?.call(true);
      } catch (e) {
        print('Failed to sync updateIsDone: $e');
        _isSynced = false;
        onSyncStatusChanged?.call(false);
      }
    }
  }

  Future<void> toggleDueToday(int todoId) async {
    final todo = await getTodoById(todoId);
    if (todo != null) {
      final now = DateTime.now();
      final todayMs = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final isDueToday = todo.dueDate == todayMs;
      if (!isDueToday) {
        todo.savedDueDate = todo.dueDate;
        todo.dueDate = todayMs;
      } else {
        todo.dueDate = todo.savedDueDate;
        todo.savedDueDate = null;
      }
      await database.update('todos', todo.toJson(), where: 'id = ?', whereArgs: [todoId]);
      try {
        await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
        _isSynced = true;
        onSyncStatusChanged?.call(true);
      } catch (e) {
        print('Failed to sync toggleDueToday: $e');
        _isSynced = false;
        onSyncStatusChanged?.call(false);
      }
    }
  }

  Future<int> addGroup(String name, Color color) async {
    final userId = await getUserId();
    final group = Group(name: name, color: color.value, userId: userId);
    final id = await database.insert('groups', group.toJson());
    group.id = id;
    try {
      await http.post(Uri.parse('$serverUrl/groups'), headers: _headers, body: jsonEncode([group.toJson()]));
      _isSynced = true;
      onSyncStatusChanged?.call(true);
    } catch (e) {
      print('Failed to sync addGroup: $e');
      _isSynced = false;
      onSyncStatusChanged?.call(false);
    }
    return id;
  }

  Future<List<Group>> getGroups() async {
    final results = await database.query('groups');
    return results.map((json) => Group.fromJson(json)).toList();
  }

  Future<void> editGroup(int groupId, String name, Color color) async {
    final group = await getGroupById(groupId);
    if (group != null) {
      group.name = name;
      group.color = color.value;
      await database.update('groups', group.toJson(), where: 'id = ?', whereArgs: [groupId]);
      try {
        await http.post(Uri.parse('$serverUrl/groups'), headers: _headers, body: jsonEncode([group.toJson()]));
        _isSynced = true;
        onSyncStatusChanged?.call(true);
      } catch (e) {
        print('Failed to sync editGroup: $e');
        _isSynced = false;
        onSyncStatusChanged?.call(false);
      }
    }
  }

  Future<void> deleteGroup(int groupId) async {
    await database.update('todos', {'group_id': null}, where: 'group_id = ?', whereArgs: [groupId]);
    await database.delete('groups', where: 'id = ?', whereArgs: [groupId]);
    try {
      await http.delete(Uri.parse('$serverUrl/groups/$groupId'), headers: _headers);
      _isSynced = true;
      onSyncStatusChanged?.call(true);
    } catch (e) {
      print('Failed to sync deleteGroup: $e');
      _isSynced = false;
      onSyncStatusChanged?.call(false);
    }
  }

  Future<String?> getSetting(String key) async {
    final result = await database.query('settings', where: 'key = ?', whereArgs: [key]);
    return result.isNotEmpty ? result.first['value'] as String? : null;
  }

  Future<void> setSetting(String key, String value) async {
    final userId = await getUserId();
    final setting = Setting(key: key, userId: userId, value: value);
    await database.insert('settings', setting.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    try {
      await http.post(Uri.parse('$serverUrl/settings'), headers: _headers, body: jsonEncode([setting.toJson()]));
      _isSynced = true;
      onSyncStatusChanged?.call(true);
    } catch (e) {
      print('Failed to sync setSetting: $e');
      _isSynced = false;
      onSyncStatusChanged?.call(false);
    }
  }

  Stream<List<Todo>> getFilteredTodosStream(bool Function(Todo)? filter, String sortOption) {
    return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
      final todos = await getAllTodos();
      var filtered = todos.where(filter ?? (t) => true).toList();
      filtered.sort((a, b) {
        if (sortOption == 'custom') return a.order.compareTo(b.order);
        switch (sortOption) {
          case 'created_desc':
            return b.createdAt.compareTo(a.createdAt);
          case 'created_asc':
            return a.createdAt.compareTo(b.createdAt);
          case 'due_asc':
            final large = 9223372036854775807;
            return (a.dueDate ?? large).compareTo(b.dueDate ?? large);
          default:
            return 0;
        }
      });
      return filtered;
    });
  }

  Future<List<Todo>> getAllTodos() async {
    final results = await database.query('todos');
    return results.map((json) => Todo.fromJson(json)).toList();
  }

  Future<Todo?> getTodoById(int id) async {
    final results = await database.query('todos', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? Todo.fromJson(results.first) : null;
  }

  Future<Todo?> getTodoByIdSync(int id) async {
    final results = await database.rawQuery('SELECT * FROM todos WHERE id = ?', [id]);
    return results.isNotEmpty ? Todo.fromJson(results.first) : null;
  }

  Future<Group?> getGroupById(int id) async {
    final results = await database.query('groups', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? Group.fromJson(results.first) : null;
  }

  Future<List<Setting>> getAllSettings() async {
    final results = await database.query('settings');
    return results.map((json) => Setting.fromJson(json)).toList();
  }
}