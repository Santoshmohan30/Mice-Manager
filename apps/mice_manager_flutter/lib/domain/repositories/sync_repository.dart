import '../models/sync_package.dart';
import '../models/update_manifest.dart';

abstract class SyncRepository {
  Future<void> saveSyncPackage(SyncPackage syncPackage);
  Future<List<SyncPackage>> listSyncPackages();
  Future<void> saveUpdateManifest(UpdateManifest manifest);
  Future<UpdateManifest?> latestManifest();
}
