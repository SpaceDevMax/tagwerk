// models/models.dart
import 'package:isar/isar.dart';

part 'models.g.dart';

@collection
class Todo {
  Id id = Isar.autoIncrement;

  late String title;

  late String description;

  late bool isDone;

  int? dueDate;

  int? completedAt;

  @Index()
  int? groupId;

  late int order;

  late List<Subtask> subtasks;

  int? savedDueDate;

  late int createdAt;

  late String userId;

  Todo({
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
    required this.userId
  });

  Todo copyWith({
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
      'is_done': isDone,
      'due_date': dueDate,
      'completed_at': completedAt,
      'group_id': groupId,
      'order': order,
      'subtasks': subtasks.map((s) => s.toJson()).toList(),
      'saved_due_date': savedDueDate,
      'created_at': createdAt,
      'user_id': userId
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      title: json['title'] as String,
      description: json['description'] as String,
      isDone: json['is_done'] as bool? ??false,
      dueDate: json['due_date'] as int?,
      completedAt: json['completed_at'] as int?,
      groupId: json['group_id'] as int?,
      order: json['order'] as int,
      subtasks: (json['subtasks'] as List).map((s) => Subtask.fromJson(s)).toList(),
      savedDueDate: json['saved_due_date'] as int?,
      createdAt: json['created_at'] as int,
      userId: json['user_id'] as String,
    )..id = json['id'] as int;
  }
}

@embedded
class Subtask {
  String title = '';

  bool isDone = false;

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
      title: json['title'] as String,
      isDone: json['is_done'] as bool,
    );
  }
}

@collection
class Group {
  Id id = Isar.autoIncrement;

  late String name;

  late int color;

  late String userId;

  Group({
    required this.name,
    required this.color,
    required this.userId,
  });

  Group copyWith({
    String? name,
    int? color,
    String? userId,
  }) {
    return Group(
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
      name: json['name'] as String,
      color: json['color'] as int,
      userId: json['user_id'] as String,
    )..id = json['id'] as int;
  }
}

@collection
class Setting {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String key;

  late String userId;

  String? value;

  Setting({required this.key, required this.userId, this.value});

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
      key: json['key'] as String,
      userId: json['user_id'] as String,
      value: json['value'] as String?,
    )..id = json['id'] as int;
  }
}