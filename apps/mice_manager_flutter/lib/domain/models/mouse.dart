import 'housing_type.dart';

class Mouse {
  const Mouse({
    required this.id,
    required this.housingType,
    required this.strain,
    required this.gender,
    required this.genotype,
    required this.dateOfBirth,
    required this.cageNumber,
    required this.isAlive,
    required this.status,
    this.rackLocation,
    this.room,
    this.dateOfDeath,
    this.deathReason,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final HousingType housingType;
  final String strain;
  final String gender;
  final String genotype;
  final DateTime dateOfBirth;
  final String cageNumber;
  final String? rackLocation;
  final String? room;
  final bool isAlive;
  final String status;
  final DateTime? dateOfDeath;
  final String? deathReason;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get ageInDays => DateTime.now().difference(dateOfBirth).inDays;
  int get ageInMonths {
    final now = DateTime.now();
    var months =
        (now.year - dateOfBirth.year) * 12 + now.month - dateOfBirth.month;
    if (now.day < dateOfBirth.day) {
      months -= 1;
    }
    return months < 0 ? 0 : months;
  }

  String get ageBucketLabel {
    final months = ageInMonths;
    if (months <= 0) {
      return '1 month old';
    }
    if (months >= 12) {
      return '1+ year old';
    }
    return '$months month old';
  }

  Mouse copyWith({
    String? id,
    HousingType? housingType,
    String? strain,
    String? gender,
    String? genotype,
    DateTime? dateOfBirth,
    String? cageNumber,
    String? rackLocation,
    String? room,
    bool? isAlive,
    String? status,
    DateTime? dateOfDeath,
    String? deathReason,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Mouse(
      id: id ?? this.id,
      housingType: housingType ?? this.housingType,
      strain: strain ?? this.strain,
      gender: gender ?? this.gender,
      genotype: genotype ?? this.genotype,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      cageNumber: cageNumber ?? this.cageNumber,
      rackLocation: rackLocation ?? this.rackLocation,
      room: room ?? this.room,
      isAlive: isAlive ?? this.isAlive,
      status: status ?? this.status,
      dateOfDeath: dateOfDeath ?? this.dateOfDeath,
      deathReason: deathReason ?? this.deathReason,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'housing_type': housingType.storageValue,
      'strain': strain,
      'gender': gender,
      'genotype': genotype,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'cage_number': cageNumber,
      'rack_location': rackLocation,
      'room': room,
      'is_alive': isAlive ? 1 : 0,
      'status': status,
      'date_of_death': dateOfDeath?.toIso8601String(),
      'death_reason': deathReason,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Mouse.fromMap(Map<String, Object?> map) {
    return Mouse(
      id: map['id'] as String,
      housingType: housingTypeFromStorage(map['housing_type'] as String),
      strain: map['strain'] as String,
      gender: map['gender'] as String,
      genotype: map['genotype'] as String,
      dateOfBirth: DateTime.parse(map['date_of_birth'] as String),
      cageNumber: map['cage_number'] as String,
      rackLocation: map['rack_location'] as String?,
      room: map['room'] as String?,
      isAlive: (map['is_alive'] as int) == 1,
      status: map['status'] as String,
      dateOfDeath: map['date_of_death'] == null
          ? null
          : DateTime.parse(map['date_of_death'] as String),
      deathReason: map['death_reason'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String),
    );
  }
}
