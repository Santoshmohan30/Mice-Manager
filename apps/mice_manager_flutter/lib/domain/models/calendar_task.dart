class CalendarTask {
  const CalendarTask({
    required this.id,
    required this.title,
    required this.taskType,
    required this.dueDate,
    required this.isDone,
    required this.createdAt,
    required this.updatedAt,
    this.sourceType,
    this.sourceId,
    this.notes,
    this.completedAt,
  });

  final String id;
  final String title;
  final String taskType;
  final DateTime dueDate;
  final bool isDone;
  final String? sourceType;
  final String? sourceId;
  final String? notes;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  CalendarTask copyWith({
    String? id,
    String? title,
    String? taskType,
    DateTime? dueDate,
    bool? isDone,
    String? sourceType,
    String? sourceId,
    String? notes,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CalendarTask(
      id: id ?? this.id,
      title: title ?? this.title,
      taskType: taskType ?? this.taskType,
      dueDate: dueDate ?? this.dueDate,
      isDone: isDone ?? this.isDone,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      notes: notes ?? this.notes,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'task_type': taskType,
      'due_date': dueDate.toIso8601String(),
      'is_done': isDone ? 1 : 0,
      'source_type': sourceType,
      'source_id': sourceId,
      'notes': notes,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CalendarTask.fromMap(Map<String, Object?> map) {
    return CalendarTask(
      id: map['id'] as String,
      title: map['title'] as String,
      taskType: map['task_type'] as String,
      dueDate: DateTime.parse(map['due_date'] as String),
      isDone: (map['is_done'] as int) == 1,
      sourceType: map['source_type'] as String?,
      sourceId: map['source_id'] as String?,
      notes: map['notes'] as String?,
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.parse(map['completed_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
