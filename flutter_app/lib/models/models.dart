import 'dart:convert';

class Todo {
  int? id;
  String title;
  String description;
  bool isDone;
  int? dueDate;
  int? completedAt;
  int? groupId;
  int order;
  List<Subtask> subtasks;
  int? savedDueDate;
  int createdAt;
  String userId;

  Todo({
    this.id,
    required this.title,
    required this.description,
    required this.isDone,
    this.dueDate,
    this.completedAt,
    this.groupId,
    required this.order,
    required this.subtasks,
    this.savedDueDate,
    required this.createdAt,
    required this.userId,
  });

  Todo copyWith({
    int? id,
    String? title,
    String? description,
    bool? isDone,
    int? dueDate,
    int? completedAt,
    int? groupId,
    int? order,
    List<Subtask>? subtasks,
    int? savedDueDate,
    int? createdAt,
    String? userId,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isDone: isDone ?? this.isDone,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      groupId: groupId ?? this.groupId,
      order: order ?? this.order,
      subtasks: subtasks ?? this.subtasks,
      savedDueDate: savedDueDate ?? this.savedDueDate,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'is_done': isDone ? 1 : 0,
      'due_date': dueDate,
      'completed_at': completedAt,
      'group_id': groupId,
      'order_': order,
      'subtasks': jsonEncode(subtasks.map((s) => s.toJson()).toList()),
      'saved_due_date': savedDueDate,
      'created_at': createdAt,
      'user_id': userId,
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isDone: (json['is_done'] as int? ?? 0) == 1,
      dueDate: json['due_date'] as int?,
      completedAt: json['completed_at'] as int?,
      groupId: json['group_id'] as int?,
      order: json['order_'] as int? ?? 0,
      subtasks: (jsonDecode(json['subtasks'] as String? ?? '[]') as List)
          .map((s) => Subtask.fromJson(s))
          .toList(),
      savedDueDate: json['saved_due_date'] as int?,
      createdAt: json['created_at'] as int? ?? 0,
      userId: json['user_id'] as String? ?? '',
    );
  }
}

class Subtask {
  String title;
  bool isDone;

  Subtask({this.title = '', this.isDone = false});

  Subtask copyWith({
    String? title,
    bool? isDone,
  }) {
    return Subtask(
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'is_done': isDone,
    };
  }

  factory Subtask.fromJson(Map<String, dynamic> json) {
    return Subtask(
      title: json['title'] as String? ?? '',
      isDone: json['is_done'] as bool? ?? false,
    );
  }
}

class Group {
  int? id;
  String name;
  int color;
  String userId;

  Group({
    this.id,
    required this.name,
    required this.color,
    required this.userId,
  });

  Group copyWith({
    int? id,
    String? name,
    int? color,
    String? userId,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      userId: userId ?? this.userId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'user_id': userId,
    };
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      color: json['color'] as int? ?? 0,
      userId: json['user_id'] as String? ?? '',
    );
  }
}

class Setting {
  int? id;
  String key;
  String userId;
  String? value;

  Setting({this.id, required this.key, required this.userId, this.value});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'value': value,
      'user_id': userId,
    };
  }

  factory Setting.fromJson(Map<String, dynamic> json) {
    return Setting(
      id: json['id'] as int?,
      key: json['key'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      value: json['value'] as String?,
    );
  }
}