class DeviceTrust {
  const DeviceTrust({
    required this.id,
    required this.deviceId,
    required this.displayName,
    required this.publicKeyFingerprint,
    required this.isTrusted,
    required this.approvedByOwner,
    this.lastSeenAt,
  });

  final String id;
  final String deviceId;
  final String displayName;
  final String publicKeyFingerprint;
  final bool isTrusted;
  final bool approvedByOwner;
  final DateTime? lastSeenAt;
}
