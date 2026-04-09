class FoodRestrictionMouse {
  const FoodRestrictionMouse({
    required this.id,
    required this.experimentId,
    required this.serialNo,
    required this.mouseType,
    required this.groupName,
    required this.gender,
    this.baselineWeightGrams,
    required this.mouseName,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String experimentId;
  final String serialNo;
  final String mouseType;
  final String groupName;
  final String gender;
  final double? baselineWeightGrams;
  final String mouseName;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'experiment_id': experimentId,
      'serial_no': serialNo,
      'mouse_type': mouseType,
      'group_name': groupName,
      'gender': gender,
      'baseline_weight_grams': baselineWeightGrams,
      'mouse_name': mouseName,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FoodRestrictionMouse.fromMap(Map<String, Object?> map) {
    return FoodRestrictionMouse(
      id: map['id'] as String,
      experimentId: map['experiment_id'] as String,
      serialNo: map['serial_no'] as String,
      mouseType: map['mouse_type'] as String,
      groupName: map['group_name'] as String,
      gender: map['gender'] as String,
      baselineWeightGrams: map['baseline_weight_grams'] == null
          ? null
          : (map['baseline_weight_grams'] as num).toDouble(),
      mouseName: map['mouse_name'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  FoodRestrictionMouse copyWith({
    String? id,
    String? experimentId,
    String? serialNo,
    String? mouseType,
    String? groupName,
    String? gender,
    double? baselineWeightGrams,
    bool clearBaseline = false,
    String? mouseName,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FoodRestrictionMouse(
      id: id ?? this.id,
      experimentId: experimentId ?? this.experimentId,
      serialNo: serialNo ?? this.serialNo,
      mouseType: mouseType ?? this.mouseType,
      groupName: groupName ?? this.groupName,
      gender: gender ?? this.gender,
      baselineWeightGrams: clearBaseline
          ? null
          : baselineWeightGrams ?? this.baselineWeightGrams,
      mouseName: mouseName ?? this.mouseName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
