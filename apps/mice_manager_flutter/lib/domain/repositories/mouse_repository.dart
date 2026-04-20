import '../models/mouse.dart';
import '../models/mouse_archive_snapshot.dart';
import '../models/housing_type.dart';

abstract class MouseRepository {
  Future<List<Mouse>> listAll();
  Future<List<Mouse>> listByHousingType(HousingType housingType);
  Future<Mouse?> findById(String mouseId);
  Future<void> save(Mouse mouse);
  Future<void> delete(String mouseId);
  Future<void> saveArchiveSnapshot(MouseArchiveSnapshot snapshot);
  Future<List<MouseArchiveSnapshot>> listArchiveSnapshots();
  Future<void> markSnapshotRestored(
    String snapshotId, {
    String? restoredBy,
  });
}
