class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.createdAt,
    required this.packagePath,
    required this.minSupportedVersion,
    this.releaseNotes,
  });

  final String version;
  final DateTime createdAt;
  final String packagePath;
  final String minSupportedVersion;
  final String? releaseNotes;
}
