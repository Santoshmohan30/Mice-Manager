class OCRDocument {
  const OCRDocument({
    required this.id,
    required this.deviceId,
    required this.sourcePath,
    required this.rawText,
    required this.reviewStatus,
    required this.capturedAt,
    this.deletedAt,
    this.parsedFields = const <String, String>{},
    this.imageMetadata = const <String, String>{},
  });

  final String id;
  final String deviceId;
  final String sourcePath;
  final String rawText;
  final Map<String, String> parsedFields;
  final Map<String, String> imageMetadata;
  final String reviewStatus;
  final DateTime capturedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'source_path': sourcePath,
      'raw_text': rawText,
      'parsed_fields_json': parsedFields.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('||'),
      'image_metadata_json': imageMetadata.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('||'),
      'review_status': reviewStatus,
      'captured_at': capturedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory OCRDocument.fromMap(Map<String, Object?> map) {
    Map<String, String> decode(String? value) {
      if (value == null || value.isEmpty) {
        return <String, String>{};
      }
      final result = <String, String>{};
      for (final pair in value.split('||')) {
        final parts = pair.split('=');
        if (parts.length >= 2) {
          result[parts.first] = parts.sublist(1).join('=');
        }
      }
      return result;
    }

    return OCRDocument(
      id: map['id'] as String,
      deviceId: map['device_id'] as String,
      sourcePath: map['source_path'] as String,
      rawText: map['raw_text'] as String,
      parsedFields: decode(map['parsed_fields_json'] as String?),
      imageMetadata: decode(map['image_metadata_json'] as String?),
      reviewStatus: map['review_status'] as String,
      capturedAt: DateTime.parse(map['captured_at'] as String),
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.parse(map['deleted_at'] as String),
    );
  }

  OCRDocument copyWith({
    String? id,
    String? deviceId,
    String? sourcePath,
    String? rawText,
    Map<String, String>? parsedFields,
    Map<String, String>? imageMetadata,
    String? reviewStatus,
    DateTime? capturedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return OCRDocument(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      sourcePath: sourcePath ?? this.sourcePath,
      rawText: rawText ?? this.rawText,
      parsedFields: parsedFields ?? this.parsedFields,
      imageMetadata: imageMetadata ?? this.imageMetadata,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      capturedAt: capturedAt ?? this.capturedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
