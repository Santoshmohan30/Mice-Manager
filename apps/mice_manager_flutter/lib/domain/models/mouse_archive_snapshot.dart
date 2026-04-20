import 'dart:convert';

import 'mouse.dart';

class MouseArchiveSnapshot {
  const MouseArchiveSnapshot({
    required this.id,
    required this.sourceMouseId,
    required this.archivedAt,
    required this.archiveReason,
    required this.strain,
    required this.cageNumber,
    required this.snapshotJson,
    this.archivedBy,
    this.restoredAt,
    this.restoredBy,
  });

  final String id;
  final String sourceMouseId;
  final DateTime archivedAt;
  final String archiveReason;
  final String strain;
  final String cageNumber;
  final String snapshotJson;
  final String? archivedBy;
  final DateTime? restoredAt;
  final String? restoredBy;

  bool get isRestored => restoredAt != null;

  Mouse restoreMouse() {
    final decoded = jsonDecode(snapshotJson);
    return Mouse.fromMap(Map<String, Object?>.from(decoded as Map));
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'source_mouse_id': sourceMouseId,
      'archived_at': archivedAt.toIso8601String(),
      'archive_reason': archiveReason,
      'strain': strain,
      'cage_number': cageNumber,
      'snapshot_json': snapshotJson,
      'archived_by': archivedBy,
      'restored_at': restoredAt?.toIso8601String(),
      'restored_by': restoredBy,
    };
  }

  factory MouseArchiveSnapshot.fromMap(Map<String, Object?> map) {
    return MouseArchiveSnapshot(
      id: map['id'] as String,
      sourceMouseId: map['source_mouse_id'] as String,
      archivedAt: DateTime.parse(map['archived_at'] as String),
      archiveReason: (map['archive_reason'] as String?) ?? 'manual_archive',
      strain: (map['strain'] as String?) ?? '',
      cageNumber: (map['cage_number'] as String?) ?? '',
      snapshotJson: map['snapshot_json'] as String,
      archivedBy: map['archived_by'] as String?,
      restoredAt: map['restored_at'] == null
          ? null
          : DateTime.parse(map['restored_at'] as String),
      restoredBy: map['restored_by'] as String?,
    );
  }

  MouseArchiveSnapshot copyWith({
    String? id,
    String? sourceMouseId,
    DateTime? archivedAt,
    String? archiveReason,
    String? strain,
    String? cageNumber,
    String? snapshotJson,
    String? archivedBy,
    DateTime? restoredAt,
    String? restoredBy,
  }) {
    return MouseArchiveSnapshot(
      id: id ?? this.id,
      sourceMouseId: sourceMouseId ?? this.sourceMouseId,
      archivedAt: archivedAt ?? this.archivedAt,
      archiveReason: archiveReason ?? this.archiveReason,
      strain: strain ?? this.strain,
      cageNumber: cageNumber ?? this.cageNumber,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      archivedBy: archivedBy ?? this.archivedBy,
      restoredAt: restoredAt ?? this.restoredAt,
      restoredBy: restoredBy ?? this.restoredBy,
    );
  }
}
