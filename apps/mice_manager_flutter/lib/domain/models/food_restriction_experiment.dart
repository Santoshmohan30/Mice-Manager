class FoodRestrictionExperiment {
  const FoodRestrictionExperiment({
    required this.id,
    required this.name,
    required this.startedAt,
    this.description,
    this.endedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => endedAt == null;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FoodRestrictionExperiment.fromMap(Map<String, Object?> map) {
    return FoodRestrictionExperiment(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.parse(map['ended_at'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  FoodRestrictionExperiment copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? startedAt,
    DateTime? endedAt,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FoodRestrictionExperiment(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
