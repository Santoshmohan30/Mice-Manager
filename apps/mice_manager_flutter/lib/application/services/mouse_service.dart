import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../domain/models/housing_type.dart';
import '../../domain/models/mouse.dart';
import '../../domain/models/mouse_archive_snapshot.dart';
import '../../domain/repositories/mouse_repository.dart';

class MouseService {
  const MouseService(this._repository);

  final MouseRepository _repository;

  Future<List<Mouse>> listAll() async {
    final mice = await _repository.listAll();
    return mice.map(_annotateMouse).toList();
  }

  Future<List<Mouse>> listLaf() =>
      _repository.listByHousingType(HousingType.laf).then(
            (mice) => mice.map(_annotateMouse).toList(),
          );

  Future<List<Mouse>> listLab() =>
      _repository.listByHousingType(HousingType.lab).then(
            (mice) => mice.map(_annotateMouse).toList(),
          );

  Future<void> save(Mouse mouse) => _repository.save(_annotateMouse(mouse));

  Future<List<MouseArchiveSnapshot>> listArchiveSnapshots() =>
      _repository.listArchiveSnapshots();

  Future<void> delete(String mouseId, {String? archivedBy}) async {
    final mouse = await _repository.findById(mouseId);
    if (mouse == null) {
      return;
    }
    final snapshotMouse = _annotateMouse(mouse);
    final now = DateTime.now();
    final snapshot = MouseArchiveSnapshot(
      id: 'mouse-archive-${now.microsecondsSinceEpoch}',
      sourceMouseId: snapshotMouse.id,
      archivedAt: now,
      archiveReason: 'manual_archive',
      strain: snapshotMouse.strain,
      cageNumber: snapshotMouse.cageNumber,
      snapshotJson: jsonEncode(snapshotMouse.toMap()),
      archivedBy: archivedBy,
    );
    await _repository.saveArchiveSnapshot(snapshot);
    await _repository.delete(mouseId);
  }

  Future<void> restoreArchiveSnapshot(
    MouseArchiveSnapshot snapshot, {
    String? restoredBy,
  }) async {
    final mouse = _annotateMouse(snapshot.restoreMouse()).copyWith(
      updatedAt: DateTime.now(),
    );
    await _repository.save(mouse);
    await _repository.markSnapshotRestored(
      snapshot.id,
      restoredBy: restoredBy,
    );
  }

  Future<bool> hasDuplicate(Mouse candidate) async {
    final normalized = _annotateMouse(candidate);
    final mice = await _repository.listAll();
    return mice.any(
      (mouse) =>
          mouse.id != normalized.id &&
          mouse.cageNumber.trim().toUpperCase() ==
              normalized.cageNumber.trim().toUpperCase() &&
          mouse.strain.trim().toUpperCase() ==
              normalized.strain.trim().toUpperCase() &&
          mouse.gender.trim().toUpperCase() ==
              normalized.gender.trim().toUpperCase() &&
          mouse.genotype.trim().toUpperCase() ==
              normalized.genotype.trim().toUpperCase() &&
          mouse.dateOfBirth.year == normalized.dateOfBirth.year &&
          mouse.dateOfBirth.month == normalized.dateOfBirth.month &&
          mouse.dateOfBirth.day == normalized.dateOfBirth.day,
    );
  }

  Mouse _annotateMouse(Mouse mouse) {
    final notes = mouse.notes ?? '';
    final upper = notes.toUpperCase();
    final hasCranialWindow = upper.contains('CRANIAL WINDOW') ||
        RegExp(r'\bCW\b', caseSensitive: false).hasMatch(notes);
    final isImplanted =
        upper.contains('IMPLANTED') || upper.contains('IMPLANT');
    final hasGreenLens = upper.contains('GREEN LENS');
    final normalizedCageNumber =
        AppConstants.normalizeCageCardNumber(mouse.cageNumber);
    return mouse.copyWith(
      cageNumber: normalizedCageNumber,
      hasCranialWindow: mouse.hasCranialWindow || hasCranialWindow,
      isImplanted: mouse.isImplanted || isImplanted,
      hasGreenLens: mouse.hasGreenLens || hasGreenLens,
    );
  }
}
