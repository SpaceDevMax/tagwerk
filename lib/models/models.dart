import 'package:isar/isar.dart';

part 'models.g.dart';

@collection
class Todo {
  Id id = Isar.autoIncrement;

  String title;

  String description;

  bool isDone;

  int? dueDate;

  int? completedAt;

  @Index()
  int? groupId;

  double order;

  List<Subtask> subtasks;

  int? savedDueDate;

  int createdAt;

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
  });

  Todo copyWith({
    String? title,
    String? description,
    bool? isDone,
    int? dueDate,
    int? completedAt,
    int? groupId,
    double? order,
    List<Subtask>? subtasks,
    int? savedDueDate,
    int? createdAt,
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
    );
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
}

@collection
class Group {
  Id id = Isar.autoIncrement;

  String name;

  int color;

  Group({
    required this.name,
    required this.color,
  });

  Group copyWith({
    String? name,
    int? color,
  }) {
    return Group(
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}

@collection
class Setting {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String key;

  String? value;

  Setting({required this.key, this.value});
}