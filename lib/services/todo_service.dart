// services/todo_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class TodoService {
  final Isar isar;
  final supabase = Supabase.instance.client;

  TodoService(this.isar);

  Stream<List<Group>> get groupsStream => isar.groups.where().watch(fireImmediately: true);

  Future<void> startSync() async {
    await _pullFromSupabase();
    final dbChannel = supabase.channel('db-changes');
    dbChannel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'todos',
        callback: _handleRemoteTodos,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'groups',
        callback: _handleRemoteGroups,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'settings',
        callback: _handleRemoteSettings,
      )
      .subscribe();
  }

  Future<void> _syncTodosToSupabase() async {
    final todos = isar.todos.where().findAllSync();
    await supabase.from('todos').upsert(todos.map((t) => t.toJson()).toList(), onConflict: 'id');
  }

  Future<void> _syncGroupsToSupabase() async {
    final groups = isar.groups.where().findAllSync();
    await supabase.from('groups').upsert(groups.map((g) => g.toJson()).toList(), onConflict: 'id');
  }

  Future<void> _syncSettingsToSupabase() async {
    final settings = isar.settings.where().findAllSync();
    await supabase.from('settings').upsert(settings.map((s) => s.toJson()).toList(), onConflict: 'id');
  }

  Future<void> _pullFromSupabase() async {
    await _pullTodos();
    await _pullGroups();
    await _pullSettings();
  }

  Future<void> _pullTodos() async {
    final response = await supabase.from('todos').select();
    final remoteTodos = response as List<Map<String, dynamic>>;
    isar.writeTxnSync(() {
      for (var json in remoteTodos) {
        final todo = Todo.fromJson(json);
        isar.todos.putSync(todo);
      }
    });
  }

  Future<void> _pullGroups() async {
    final response = await supabase.from('groups').select();
    final remoteGroups = response as List<Map<String, dynamic>>;
    isar.writeTxnSync(() {
      for (var json in remoteGroups) {
        final group = Group.fromJson(json);
        isar.groups.putSync(group);
      }
    });
  }

  Future<void> _pullSettings() async {
    final response = await supabase.from('settings').select();
    final remoteSettings = response as List<Map<String, dynamic>>;
    isar.writeTxnSync(() {
      for (var json in remoteSettings) {
        final setting = Setting.fromJson(json);
        isar.settings.putSync(setting);
      }
    });
  }

  void _handleRemoteTodos(PostgresChangePayload payload) {
    isar.writeTxnSync(() {
      if (payload.eventType == PostgresChangeEvent.insert || payload.eventType == PostgresChangeEvent.update) {
        if (payload.newRecord != null) {
          final newTodo = Todo.fromJson(payload.newRecord!);
          isar.todos.putSync(newTodo);
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        if (payload.oldRecord != null) {
          isar.todos.deleteSync(payload.oldRecord!['id']);
        }
      }
    });
  }

  void _handleRemoteGroups(PostgresChangePayload payload) {
    isar.writeTxnSync(() {
      if (payload.eventType == PostgresChangeEvent.insert || payload.eventType == PostgresChangeEvent.update) {
        if (payload.newRecord != null) {
          final newGroup = Group.fromJson(payload.newRecord!);
          isar.groups.putSync(newGroup);
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        if (payload.oldRecord != null) {
          isar.groups.deleteSync(payload.oldRecord!['id']);
        }
      }
    });
  }

  void _handleRemoteSettings(PostgresChangePayload payload) {
    isar.writeTxnSync(() {
      if (payload.eventType == PostgresChangeEvent.insert || payload.eventType == PostgresChangeEvent.update) {
        if (payload.newRecord != null) {
          final newSetting = Setting.fromJson(payload.newRecord!);
          isar.settings.putSync(newSetting);
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        if (payload.oldRecord != null) {
          isar.settings.deleteSync(payload.oldRecord!['id']);
        }
      }
    });
  }

  Future<void> addTask(String title, String description, DateTime dueDate, [int? groupId]) async {
    if (title.isNotEmpty) {
      final currentUser = supabase.auth.currentUser;
      final todoJson = {
        'title': title,
        'description': description,
        'is_done': false,
        'due_date': dueDate.millisecondsSinceEpoch,
        'completed_at': null,
        'group_id': groupId,
        'order': DateTime.now().millisecondsSinceEpoch,
        'subtasks': [],
        'saved_due_date': null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'user_id': currentUser!.id,
      };
      final response = await supabase.from('todos').insert(todoJson).select();
      final insertedId = response[0]['id'] as int;
      final todo = Todo.fromJson({...todoJson, 'id': insertedId});
      isar.writeTxnSync(() => isar.todos.putSync(todo));
    }
  }

  Future<void> addSubtask(int todoId, String subTitle) async {
      if (subTitle.isNotEmpty) {
        Todo? todo;
        isar.writeTxnSync(() {
          todo = isar.todos.getSync(todoId);
          if (todo != null) {
            todo!.subtasks = [...todo!.subtasks, Subtask(title: subTitle, isDone: false)];
            isar.todos.putSync(todo!);
          }
        });
        if (todo != null) {
          await supabase.from('todos').update(todo!.toJson()).eq('id', todoId);
        }
      }
    }

  Future<void> toggleSubtask(int todoId, int subIndex, bool isDone) async {
    Todo? todo;
    isar.writeTxnSync(() {
      todo = isar.todos.getSync(todoId);
      if (todo != null && subIndex < todo!.subtasks.length) {
        todo!.subtasks[subIndex].isDone = isDone;
        isar.todos.putSync(todo!);
      }
    });
    if (todo != null) {
      await supabase.from('todos').update(todo!.toJson()).eq('id', todoId);
    }
  }

  bool areAllSubtasksDone(int todoId) {
    final todo = isar.todos.getSync(todoId);
    if (todo != null) {
      return todo.subtasks.isNotEmpty && todo.subtasks.every((sub) => sub.isDone);
    }
    return true;
  }

  Future<void> markAllSubtasksDone(int todoId) async {
    Todo? todo;
    isar.writeTxnSync(() {
      todo = isar.todos.getSync(todoId);
      if (todo != null) {
        for (var sub in todo!.subtasks) {
          sub.isDone = true;
        }
        isar.todos.putSync(todo!);
      }
    });
    if (todo != null) {
      await supabase.from('todos').update(todo!.toJson()).eq('id', todoId);
    }
  }

  Future<void> editTask(int todoId, String title, String description, DateTime dueDate, [int? groupId]) async {
    Todo? todo;
    isar.writeTxnSync(() {
      todo = isar.todos.getSync(todoId);
      if (todo != null) {
        todo!.title = title;
        todo!.description = description;
        todo!.dueDate = dueDate.millisecondsSinceEpoch;
        if (groupId != null) {
          todo!.groupId = groupId;
        }
        isar.todos.putSync(todo!);
      }
    });
    if (todo != null) {
      await supabase.from('todos').update(todo!.toJson()).eq('id', todoId);
    }
  }

  Future<void> deleteTask(int todoId) async {
    isar.writeTxnSync(() => isar.todos.deleteSync(todoId));
    await supabase.from('todos').delete().eq('id', todoId);
  }

  Future<void> updateIsDone(int todoId, bool isDone) async {
    Todo? todo;
    isar.writeTxnSync(() {
      todo = isar.todos.getSync(todoId);
      if (todo != null) {
        int? completedAt = todo!.completedAt;
        if (isDone && !todo!.isDone) {
          completedAt = DateTime.now().millisecondsSinceEpoch;
        } else if (!isDone) {
          completedAt = null;
        }
        todo!.isDone = isDone;
        todo!.completedAt = completedAt;
        isar.todos.putSync(todo!);
      }
    });
    if (todo != null) {
      await supabase.from('todos').update(todo!.toJson()).eq('id', todoId);
    }
  }

  Future<void> toggleDueToday(int todoId) async {
    Todo? todo;
    isar.writeTxnSync(() {
      todo = isar.todos.getSync(todoId);
      if (todo != null) {
        final dueMs = todo!.dueDate;
        final savedMs = todo!.savedDueDate;
        final now = DateTime.now();
        final todayMs = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        bool isDueToday = false;
        if (dueMs != null) {
          final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
          isDueToday = due.year == now.year && due.month == now.month && due.day == now.day;
        }
        if (!isDueToday) {
          todo!.savedDueDate = dueMs;
          todo!.dueDate = todayMs;
        } else {
          todo!.dueDate = savedMs;
          todo!.savedDueDate = null;
        }
        isar.todos.putSync(todo!);
      }
    });
    if (todo != null) {
      await supabase.from('todos').update(todo!.toJson()).eq('id', todoId);
    }
  }

  Future<int> addGroup(String name, Color color) async {
    final currentUser = supabase.auth.currentUser;
    final groupJson = {
      'name': name,
      'color': color.value,
      'user_id': currentUser!.id,
    };
    final response = await supabase.from('groups').insert(groupJson).select();
    final insertedId = response[0]['id'] as int;
    final group = Group.fromJson({...groupJson, 'id': insertedId});
    isar.writeTxnSync(() => isar.groups.putSync(group));
    return insertedId;
  }

  List<Group> getGroups() {
    return isar.groups.where().findAllSync();
  }

  Future<void> editGroup(int groupId, String name, Color color) async {
    Group? group;
    isar.writeTxnSync(() {
      group = isar.groups.getSync(groupId);
      if (group != null) {
        group!.name = name;
        group!.color = color.value;
        isar.groups.putSync(group!);
      }
    });
    if (group != null) {
      await supabase.from('groups').update(group!.toJson()).eq('id', groupId);
    }
  }

  Future<void> deleteGroup(int groupId) async {
    isar.writeTxnSync(() {
      final todosToUpdate = isar.todos.where().groupIdEqualTo(groupId).findAllSync();
      for (var todo in todosToUpdate) {
        todo.groupId = null;
        isar.todos.putSync(todo);
      }
      isar.groups.deleteSync(groupId);
    });
    await supabase.from('groups').delete().eq('id', groupId);
  }

  String? getSetting(String key) {
    return isar.settings.where().keyEqualTo(key).findFirstSync()?.value;
  }

  Future<void> setSetting(String key, String value) async {
    final currentUser = supabase.auth.currentUser;
    Setting? setting = isar.settings.where().keyEqualTo(key).findFirstSync();
    if (setting == null) {
      final settingJson = {
        'key': key,
        'value': value,
        'user_id': currentUser!.id,
      };
      final response = await supabase.from('settings').insert(settingJson).select();
      final insertedId = response[0]['id'] as int;
      setting = Setting.fromJson({...settingJson, 'id': insertedId});
      isar.writeTxnSync(() => isar.settings.putSync(setting!));
    } else {
      setting.value = value;
      isar.writeTxnSync(() => isar.settings.putSync(setting!));
      await supabase.from('settings').update(setting.toJson()).eq('id', setting.id);
    }
  }

  Stream<List<Todo>> getFilteredTodosStream(bool Function(Todo)? filter, String sortOption) {
    return isar.todos.where().build().watch(fireImmediately: true).map((todos) {
      var filtered = todos.where(filter ?? (t) => true).toList();
      filtered.sort((a, b) {
        if (sortOption == 'custom') {
          return a.order.compareTo(b.order);
        }
        switch (sortOption) {
          case 'created_desc':
            return b.createdAt.compareTo(a.createdAt);
          case 'created_asc':
            return a.createdAt.compareTo(b.createdAt);
          case 'due_asc':
            final large = 9223372036854775807;
            final aDue = a.dueDate ?? large;
            final bDue = b.dueDate ?? large;
            return aDue.compareTo(bDue);
          default:
            return 0;
        }
      });
      return filtered;
    });
  }
}