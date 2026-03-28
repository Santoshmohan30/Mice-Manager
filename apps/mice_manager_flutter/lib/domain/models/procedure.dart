class Procedure {
  const Procedure({
    required this.id,
    required this.mouseId,
    required this.name,
    required this.performedAt,
    this.performedBy,
    this.notes,
  });

  final String id;
  final String mouseId;
  final String name;
  final DateTime performedAt;
  final String? performedBy;
  final String? notes;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'mouse_id': mouseId,
      'name': name,
      'performed_at': performedAt.toIso8601String(),
      'performed_by': performedBy,
      'notes': notes,
    };
  }

  factory Procedure.fromMap(Map<String, Object?> map) {
    return Procedure(
      id: map['id'] as String,
      mouseId: map['mouse_id'] as String,
      name: map['name'] as String,
      performedAt: DateTime.parse(map['performed_at'] as String),
      performedBy: map['performed_by'] as String?,
      notes: map['notes'] as String?,
    );
  }

  Procedure copyWith({
    String? id,
    String? mouseId,
    String? name,
    DateTime? performedAt,
    String? performedBy,
    String? notes,
  }) {
    return Procedure(
      id: id ?? this.id,
      mouseId: mouseId ?? this.mouseId,
      name: name ?? this.name,
      performedAt: performedAt ?? this.performedAt,
      performedBy: performedBy ?? this.performedBy,
      notes: notes ?? this.notes,
    );
  }
}
