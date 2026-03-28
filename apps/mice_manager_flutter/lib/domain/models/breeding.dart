class Breeding {
  const Breeding({
    required this.id,
    required this.maleMouseId,
    required this.femaleMouseId,
    required this.startedAt,
    this.endedAt,
    this.notes,
  });

  final String id;
  final String maleMouseId;
  final String femaleMouseId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? notes;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'male_mouse_id': maleMouseId,
      'female_mouse_id': femaleMouseId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  factory Breeding.fromMap(Map<String, Object?> map) {
    return Breeding(
      id: map['id'] as String,
      maleMouseId: map['male_mouse_id'] as String,
      femaleMouseId: map['female_mouse_id'] as String,
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.parse(map['ended_at'] as String),
      notes: map['notes'] as String?,
    );
  }

  Breeding copyWith({
    String? id,
    String? maleMouseId,
    String? femaleMouseId,
    DateTime? startedAt,
    DateTime? endedAt,
    String? notes,
  }) {
    return Breeding(
      id: id ?? this.id,
      maleMouseId: maleMouseId ?? this.maleMouseId,
      femaleMouseId: femaleMouseId ?? this.femaleMouseId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      notes: notes ?? this.notes,
    );
  }
}
