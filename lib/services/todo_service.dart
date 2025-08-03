// services/todo_service.dart
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/models.dart';

class TodoService {
  final Isar isar;

  TodoService(this.isar);

  Stream<List<Group>> get groupsStream => isar.groups.where().watch(fireImmediately: true);

  
  void addTask(String title, String description, DateTime dueDate, [int? groupId]) {
    if (title.isNotEmpty) {
      final todo = Todo(
        title: title,
        description: description,
        isDone: false,
        dueDate: dueDate.millisecondsSinceEpoch,
        completedAt: null,
        groupId: groupId,
        order: DateTime.now().millisecondsSinceEpoch.toDouble(),
        subtasks: [],
        savedDueDate: null,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      isar.writeTxnSync(() => isar.todos.putSync(todo));
    }
  }

  void addSubtask(int todoId, String subTitle) {
    if (subTitle.isNotEmpty) {
      isar.writeTxnSync(() {
        final todo = isar.todos.getSync(todoId);
        if (todo != null) {
          todo.subtasks.add(Subtask(title: subTitle, isDone: false));
          isar.todos.putSync(todo);
        }
      });
    }
  }

  void toggleSubtask(int todoId, int subIndex, bool isDone) {
    isar.writeTxnSync(() {
      final todo = isar.todos.getSync(todoId);
      if (todo != null && subIndex < todo.subtasks.length) {
        todo.subtasks[subIndex].isDone = isDone;
        isar.todos.putSync(todo);
      }
    });
  }

  bool areAllSubtasksDone(int todoId) {
    final todo = isar.todos.getSync(todoId);
    if (todo != null) {
      return todo.subtasks.isNotEmpty && todo.subtasks.every((sub) => sub.isDone);
    }
    return true;
  }

  void markAllSubtasksDone(int todoId) {
    isar.writeTxnSync(() {
      final todo = isar.todos.getSync(todoId);
      if (todo != null) {
        for (var sub in todo.subtasks) {
          sub.isDone = true;
        }
        isar.todos.putSync(todo);
      }
    });
  }

  void editTask(int todoId, String title, String description, DateTime dueDate, [int? groupId]) {
    isar.writeTxnSync(() {
      final todo = isar.todos.getSync(todoId);
      if (todo != null) {
        todo.title = title;
        todo.description = description;
        todo.dueDate = dueDate.millisecondsSinceEpoch;
        if (groupId != null) {
          todo.groupId = groupId;
        }
        isar.todos.putSync(todo);
      }
    });
  }

  void deleteTask(int todoId) {
    isar.writeTxnSync(() => isar.todos.deleteSync(todoId));
  }

  void updateIsDone(int todoId, bool isDone) {
    isar.writeTxnSync(() {
      final todo = isar.todos.getSync(todoId);
      if (todo != null) {
        int? completedAt = todo.completedAt;
        if (isDone && !todo.isDone) {
          completedAt = DateTime.now().millisecondsSinceEpoch;
        } else if (!isDone) {
          completedAt = null;
        }
        todo.isDone = isDone;
        todo.completedAt = completedAt;
        isar.todos.putSync(todo);
      }
    });
  }

  void toggleDueToday(int todoId) {
    isar.writeTxnSync(() {
      final todo = isar.todos.getSync(todoId);
      if (todo != null) {
        final dueMs = todo.dueDate;
        final savedMs = todo.savedDueDate;
        final now = DateTime.now();
        final todayMs = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        bool isDueToday = false;
        if (dueMs != null) {
          final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
          isDueToday = due.year == now.year && due.month == now.month && due.day == now.day;
        }
        if (!isDueToday) {
          todo.savedDueDate = dueMs;
          todo.dueDate = todayMs;
        } else {
          todo.dueDate = savedMs;
          todo.savedDueDate = null;
        }
        isar.todos.putSync(todo);
      }
    });
  }

  int addGroup(String name, Color color) {
    final group = Group(name: name, color: color.value);
    return isar.writeTxnSync(() => isar.groups.putSync(group));
  }

  List<Group> getGroups() {
    return isar.groups.where().findAllSync();
  }

  void editGroup(int groupId, String name, Color color) {
    isar.writeTxnSync(() {
      final group = isar.groups.getSync(groupId);
      if (group != null) {
        group.name = name;
        group.color = color.value;
        isar.groups.putSync(group);
      }
    });
  }

  void deleteGroup(int groupId) {
    isar.writeTxnSync(() {
      final todosToUpdate = isar.todos.where().groupIdEqualTo(groupId).findAllSync();
      for (var todo in todosToUpdate) {
        todo.groupId = null;
        isar.todos.putSync(todo);
      }
      isar.groups.deleteSync(groupId);
    });
  }

  String? getSetting(String key) {
    return isar.settings.where().keyEqualTo(key).findFirstSync()?.value;
  }

  void setSetting(String key, String value) {
    isar.writeTxnSync(() {
      var setting = isar.settings.where().keyEqualTo(key).findFirstSync();
      if (setting == null) {
        setting = Setting(key: key, value: value);
      } else {
        setting.value = value;
      }
      isar.settings.putSync(setting);
    });
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