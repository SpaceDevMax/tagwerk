import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import '../models/models.dart';

class TodoService {
  final Database database;
  final String serverUrl = 'http://raspberrypi.local:8080'; // Replace with your Pi IP
  String? _authToken;
  bool _isSynced = true;
  Function(bool)? onSyncStatusChanged;
  List<Group> _initialGroups = [];
  List<Todo> _initialTodos = [];
  final _groupsSubject = BehaviorSubject<List<Group>>.seeded([]);
  final _todosSubject = BehaviorSubject<List<Todo>>.seeded([]);

  TodoService(this.database) {
    _loadInitialData();
  }

  Future<void> init() async {
    await _loadAuthToken();
    await _loadInitialData();
  }

  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
  }

  Future<void> _loadInitialData() async {
    _initialGroups = await getGroups();
    _groupsSubject.add(_initialGroups);
    _initialTodos = await getAllTodos();
    _todosSubject.add(_initialTodos);
    print('Loaded initial groups: ${_initialGroups.length}, todos: ${_initialTodos.length}');
  }

  bool get isSynced => _isSynced;

  bool isLoggedIn() {
    return _authToken != null;
  }

  Stream<List<Group>> get groupsStream => _groupsSubject.stream;

  Stream<List<Todo>> getFilteredTodosStream(bool Function(Todo)? filter, String sortOption) {
    return _todosSubject.stream.map((todos) {
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
      print('getFilteredTodosStream emitted ${filtered.length} todos');
      return filtered;
    });
  }

  Future<void> startSync() async {
    Timer.periodic(const Duration(seconds: 5), (_) async {
      await _pullFromServer();
      await _syncToServer();
      _initialGroups = await getGroups();
      _groupsSubject.add(_initialGroups);
      _initialTodos = await getAllTodos();
      _todosSubject.add(_initialTodos);
      print('Sync updated groups: ${_initialGroups.length}, todos: ${_initialTodos.length}');
    });
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _authToken!);
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _authToken!);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

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
        _initialTodos = await getAllTodos(); // Refresh cache
        _todosSubject.add(_initialTodos); // Emit updated todos
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
        _initialGroups = await getGroups(); // Refresh cache
        _groupsSubject.add(_initialGroups); // Emit updated groups
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
    final start = DateTime.now();
    final id = await database.insert('todos', todo.toJson());
    todo.id = id;
    print('Local addTask took: ${DateTime.now().difference(start).inMilliseconds}ms');
    _initialTodos = [..._initialTodos, todo];
    _todosSubject.add(_initialTodos);
    Future(() async {
      try {
        await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
        _isSynced = true;
        onSyncStatusChanged?.call(true);
      } catch (e) {
        print('Failed to sync addTask: $e');
        _isSynced = false;
        onSyncStatusChanged?.call(false);
      }
    });
  }

  Future<String> getUserId() async {
    return 'local-user';
  }

  Future<void> addSubtask(int todoId, String subTitle) async {
    if (subTitle.isEmpty) return;
    final todo = await getTodoById(todoId);
    if (todo != null) {
      final start = DateTime.now();
      todo.subtasks.add(Subtask(title: subTitle));
      await database.update('todos', todo.toJson(), where: 'id = ?', whereArgs: [todoId]);
      print('Local addSubtask took: ${DateTime.now().difference(start).inMilliseconds}ms');
      _initialTodos = _initialTodos.map((t) => t.id == todoId ? todo : t).toList();
      _todosSubject.add(_initialTodos);
      Future(() async {
        try {
          await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
          _isSynced = true;
          onSyncStatusChanged?.call(true);
        } catch (e) {
          print('Failed to sync addSubtask: $e');
          _isSynced = false;
          onSyncStatusChanged?.call(false);
        }
      });
    }
  }

  Future<void> toggleSubtask(int todoId, int subIndex, bool isDone) async {
    final todo = await getTodoById(todoId);
    if (todo != null && subIndex < todo.subtasks.length) {
      final start = DateTime.now();
      todo.subtasks[subIndex].isDone = isDone;
      await database.update('todos', todo.toJson(), where: 'id = ?', whereArgs: [todoId]);
      print('Local toggleSubtask took: ${DateTime.now().difference(start).inMilliseconds}ms');
      _initialTodos = _initialTodos.map((t) => t.id == todoId ? todo : t).toList();
      _todosSubject.add(_initialTodos);
      Future(() async {
        try {
          await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
          _isSynced = true;
          onSyncStatusChanged?.call(true);
        } catch (e) {
          print('Failed to sync toggleSubtask: $e');
          _isSynced = false;
          onSyncStatusChanged?.call(false);
        }
      });
    }
  }

  Future<bool> areAllSubtasksDone(int todoId) async {
    final todo = await getTodoByIdSync(todoId);
    return todo != null && todo.subtasks.isNotEmpty && todo.subtasks.every((sub) => sub.isDone);
  }

  Future<void> markAllSubtasksDone(int todoId) async {
    final todo = await getTodoById(todoId);
    if (todo != null) {
      final start = DateTime.now();
      for (var sub in todo.subtasks) {
        sub.isDone = true;
      }
      await database.update('todos', todo.toJson(), where: 'id = ?', whereArgs: [todoId]);
      print('Local markAllSubtasksDone took: ${DateTime.now().difference(start).inMilliseconds}ms');
      _initialTodos = _initialTodos.map((t) => t.id == todoId ? todo : t).toList();
      _todosSubject.add(_initialTodos);
      Future(() async {
        try {
          await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
          _isSynced = true;
          onSyncStatusChanged?.call(true);
        } catch (e) {
          print('Failed to sync markAllSubtasksDone: $e');
          _isSynced = false;
          onSyncStatusChanged?.call(false);
        }
      });
    }
  }

  Future<void> editTask(int todoId, String title, String description, DateTime dueDate, List<Subtask> subtasks, [int? groupId]) async {
    final todo = await getTodoById(todoId);
    if (todo != null) {
      final start = DateTime.now();
      todo.title = title;
      todo.description = description;
      todo.dueDate = dueDate.millisecondsSinceEpoch;
      todo.groupId = groupId ?? todo.groupId;
      todo.subtasks = subtasks;
      await database.update('todos', todo.toJson(), where: 'id = ?', whereArgs: [todoId]);
      print('Local editTask took: ${DateTime.now().difference(start).inMilliseconds}ms');
      _initialTodos = _initialTodos.map((t) => t.id == todoId ? todo : t).toList();
      _todosSubject.add(_initialTodos);
      Future(() async {
        try {
          await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
          _isSynced = true;
          onSyncStatusChanged?.call(true);
        } catch (e) {
          print('Failed to sync editTask: $e');
          _isSynced = false;
          onSyncStatusChanged?.call(false);
        }
      });
    }
  }

  Future<void> deleteTask(int todoId) async {
    final start = DateTime.now();
    await database.delete('todos', where: 'id = ?', whereArgs: [todoId]);
    print('Local deleteTask took: ${DateTime.now().difference(start).inMilliseconds}ms');
    _initialTodos = _initialTodos.where((t) => t.id != todoId).toList();
    _todosSubject.add(_initialTodos);
    Future(() async {
      try {
        await http.delete(Uri.parse('$serverUrl/todos/$todoId'), headers: _headers);
        _isSynced = true;
        onSyncStatusChanged?.call(true);
      } catch (e) {
        print('Failed to sync deleteTask: $e');
        _isSynced = false;
        onSyncStatusChanged?.call(false);
      }
    });
  }

  Future<void> updateIsDone(int todoId, bool isDone) async {
    final todo = await getTodoById(todoId);
    if (todo != null) {
      final start = DateTime.now();
      todo.isDone = isDone;
      todo.completedAt = isDone ? DateTime.now().millisecondsSinceEpoch : null;
      await database.update('todos', todo.toJson(), where: 'id = ?', whereArgs: [todoId]);
      print('Local updateIsDone took: ${DateTime.now().difference(start).inMilliseconds}ms');
      _initialTodos = _initialTodos.map((t) => t.id == todoId ? todo : t).toList();
      _todosSubject.add(_initialTodos);
      Future(() async {
        try {
          await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
          _isSynced = true;
          onSyncStatusChanged?.call(true);
        } catch (e) {
          print('Failed to sync updateIsDone: $e');
          _isSynced = false;
          onSyncStatusChanged?.call(false);
        }
      });
    }
  }

  Future<void> toggleDueToday(int todoId) async {
    final todo = await getTodoById(todoId);
    if (todo != null) {
      final start = DateTime.now();
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
      print('Local toggleDueToday took: ${DateTime.now().difference(start).inMilliseconds}ms');
      _initialTodos = _initialTodos.map((t) => t.id == todoId ? todo : t).toList();
      _todosSubject.add(_initialTodos);
      Future(() async {
        try {
          await http.post(Uri.parse('$serverUrl/todos'), headers: _headers, body: jsonEncode([todo.toJson()]));
          _isSynced = true;
          onSyncStatusChanged?.call(true);
        } catch (e) {
          print('Failed to sync toggleDueToday: $e');
          _isSynced = false;
          onSyncStatusChanged?.call(false);
        }
      });
    }
  }

  Future<int> addGroup(String name, Color color) async {
    final userId = await getUserId();
    final group = Group(name: name, color: color.value, userId: userId);
    final start = DateTime.now();
    final id = await database.insert('groups', group.toJson());
    group.id = id;
    print('Local addGroup took: ${DateTime.now().difference(start).inMilliseconds}ms');
    _initialGroups = [..._initialGroups, group];
    _groupsSubject.add(_initialGroups);
    Future(() async {
      try {
        await http.post(Uri.parse('$serverUrl/groups'), headers: _headers, body: jsonEncode([group.toJson()]));
        _isSynced = true;
        onSyncStatusChanged?.call(true);
      } catch (e) {
        print('Failed to sync addGroup: $e');
        _isSynced = false;
        onSyncStatusChanged?.call(false);
      }
    });
    return id;
  }

  Future<List<Group>> getGroups() async {
    final start = DateTime.now();
    final results = await database.query('groups', orderBy: 'name');
    final groups = results.map((json) => Group.fromJson(json)).toList();
    print('getGroups took: ${DateTime.now().difference(start).inMilliseconds}ms, returned ${groups.length} groups');
    return groups;
  }

  Future<void> editGroup(int groupId, String name, Color color) async {
    final group = await getGroupById(groupId);
    if (group != null) {
      final start = DateTime.now();
      group.name = name;
      group.color = color.value;
      await database.update('groups', group.toJson(), where: 'id = ?', whereArgs: [groupId]);
      print('Local editGroup took: ${DateTime.now().difference(start).inMilliseconds}ms');
      _initialGroups = _initialGroups.map((g) => g.id == groupId ? group : g).toList();
      _groupsSubject.add(_initialGroups);
      Future(() async {
        try {
          await http.post(Uri.parse('$serverUrl/groups'), headers: _headers, body: jsonEncode([group.toJson()]));
          _isSynced = true;
          onSyncStatusChanged?.call(true);
        } catch (e) {
          print('Failed to sync editGroup: $e');
          _isSynced = false;
          onSyncStatusChanged?.call(false);
        }
      });
    }
  }

  Future<void> deleteGroup(int groupId) async {
    final start = DateTime.now();
    await database.update('todos', {'group_id': null}, where: 'group_id = ?', whereArgs: [groupId]);
    await database.delete('groups', where: 'id = ?', whereArgs: [groupId]);
    print('Local deleteGroup took: ${DateTime.now().difference(start).inMilliseconds}ms');
    _initialTodos = _initialTodos.map((t) => t.groupId == groupId ? t.copyWith(groupId: null) : t).toList();
    _initialGroups = _initialGroups.where((g) => g.id != groupId).toList();
    _todosSubject.add(_initialTodos);
    _groupsSubject.add(_initialGroups);
    Future(() async {
      try {
        await http.delete(Uri.parse('$serverUrl/groups/$groupId'), headers: _headers);
        _isSynced = true;
        onSyncStatusChanged?.call(true);
      } catch (e) {
        print('Failed to sync deleteGroup: $e');
        _isSynced = false;
        onSyncStatusChanged?.call(false);
      }
    });
  }

  Future<String?> getSetting(String key) async {
    final start = DateTime.now();
    final result = await database.query('settings', where: 'key = ?', whereArgs: [key]);
    print('getSetting took: ${DateTime.now().difference(start).inMilliseconds}ms');
    return result.isNotEmpty ? result.first['value'] as String? : null;
  }

  Future<void> setSetting(String key, String value) async {
    final userId = await getUserId();
    final setting = Setting(key: key, userId: userId, value: value);
    final start = DateTime.now();
    await database.insert('settings', setting.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    print('Local setSetting took: ${DateTime.now().difference(start).inMilliseconds}ms');
    Future(() async {
      try {
        await http.post(Uri.parse('$serverUrl/settings'), headers: _headers, body: jsonEncode([setting.toJson()]));
        _isSynced = true;
        onSyncStatusChanged?.call(true);
      } catch (e) {
        print('Failed to sync setSetting: $e');
        _isSynced = false;
        onSyncStatusChanged?.call(false);
      }
    });
  }

  Future<List<Todo>> getAllTodos() async {
    final start = DateTime.now();
    final results = await database.query('todos', orderBy: 'created_at');
    final todos = results.map((json) => Todo.fromJson(json)).toList();
    print('getAllTodos took: ${DateTime.now().difference(start).inMilliseconds}ms, returned ${todos.length} todos');
    return todos;
  }

  Future<Todo?> getTodoById(int id) async {
    final start = DateTime.now();
    final results = await database.query('todos', where: 'id = ?', whereArgs: [id]);
    print('getTodoById took: ${DateTime.now().difference(start).inMilliseconds}ms');
    return results.isNotEmpty ? Todo.fromJson(results.first) : null;
  }

  Future<Todo?> getTodoByIdSync(int id) async {
    final start = DateTime.now();
    final results = await database.rawQuery('SELECT * FROM todos WHERE id = ?', [id]);
    print('getTodoByIdSync took: ${DateTime.now().difference(start).inMilliseconds}ms');
    return results.isNotEmpty ? Todo.fromJson(results.first) : null;
  }

  Future<Group?> getGroupById(int id) async {
    final start = DateTime.now();
    final results = await database.query('groups', where: 'id = ?', whereArgs: [id]);
    print('getGroupById took: ${DateTime.now().difference(start).inMilliseconds}ms');
    return results.isNotEmpty ? Group.fromJson(results.first) : null;
  }

  Future<List<Setting>> getAllSettings() async {
    final start = DateTime.now();
    final results = await database.query('settings');
    print('getAllSettings took: ${DateTime.now().difference(start).inMilliseconds}ms');
    return results.map((json) => Setting.fromJson(json)).toList();
  }
}