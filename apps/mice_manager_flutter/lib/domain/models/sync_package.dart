class SyncPackage {
  const SyncPackage({
    required this.id,
    required this.version,
    required this.createdAt,
    required this.deviceSourceId,
    required this.bundlePath,
    this.notes,
  });

  final String id;
  final String version;
  final DateTime createdAt;
  final String deviceSourceId;
  final String bundlePath;
  final String? notes;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'device_source_id': deviceSourceId,
      'bundle_path': bundlePath,
      'notes': notes,
    };
  }

  factory SyncPackage.fromMap(Map<String, Object?> map) {
    return SyncPackage(
      id: map['id'] as String,
      version: map['version'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      deviceSourceId: map['device_source_id'] as String,
      bundlePath: map['bundle_path'] as String,
      notes: map['notes'] as String?,
    );
  }
}
