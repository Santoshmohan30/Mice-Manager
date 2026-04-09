class FoodRestrictionEntry {
  const FoodRestrictionEntry({
    required this.id,
    required this.experimentMouseId,
    required this.entryDate,
    required this.personPerforming,
    required this.weightGrams,
    this.foodWeightGrams,
    this.conditionLabel,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String experimentMouseId;
  final DateTime entryDate;
  final String personPerforming;
  final double weightGrams;
  final double? foodWeightGrams;
  final String? conditionLabel;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'experiment_mouse_id': experimentMouseId,
      'entry_date': entryDate.toIso8601String(),
      'person_performing': personPerforming,
      'weight_grams': weightGrams,
      'food_weight_grams': foodWeightGrams,
      'condition_label': conditionLabel,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FoodRestrictionEntry.fromMap(Map<String, Object?> map) {
    return FoodRestrictionEntry(
      id: map['id'] as String,
      experimentMouseId: map['experiment_mouse_id'] as String,
      entryDate: DateTime.parse(map['entry_date'] as String),
      personPerforming: map['person_performing'] as String,
      weightGrams: (map['weight_grams'] as num).toDouble(),
      foodWeightGrams: map['food_weight_grams'] == null
          ? null
          : (map['food_weight_grams'] as num).toDouble(),
      conditionLabel: map['condition_label'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  FoodRestrictionEntry copyWith({
    String? id,
    String? experimentMouseId,
    DateTime? entryDate,
    String? personPerforming,
    double? weightGrams,
    double? foodWeightGrams,
    bool clearFoodWeight = false,
    String? conditionLabel,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FoodRestrictionEntry(
      id: id ?? this.id,
      experimentMouseId: experimentMouseId ?? this.experimentMouseId,
      entryDate: entryDate ?? this.entryDate,
      personPerforming: personPerforming ?? this.personPerforming,
      weightGrams: weightGrams ?? this.weightGrams,
      foodWeightGrams:
          clearFoodWeight ? null : foodWeightGrams ?? this.foodWeightGrams,
      conditionLabel: conditionLabel ?? this.conditionLabel,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ComputedFoodRestrictionEntry {
  const ComputedFoodRestrictionEntry({
    required this.entry,
    required this.percentOfOriginal,
    required this.percentChange,
    required this.isBaseline,
    required this.isConcerning,
  });

  final FoodRestrictionEntry entry;
  final double percentOfOriginal;
  final double? percentChange;
  final bool isBaseline;
  final bool isConcerning;
}
