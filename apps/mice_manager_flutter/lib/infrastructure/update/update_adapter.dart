abstract class UpdateAdapter {
  Future<void> publishManifest();
  Future<void> publishBundle();
  Future<void> promptForUpdate();
}

// TODO(local-lan-updater): Implement local/LAN update manifests and bundle transfer.
