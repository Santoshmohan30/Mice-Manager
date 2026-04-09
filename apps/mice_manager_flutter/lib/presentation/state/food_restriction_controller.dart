import 'package:flutter/foundation.dart';

import '../../application/services/food_restriction_service.dart';
import '../../domain/models/food_restriction_entry.dart';
import '../../domain/models/food_restriction_experiment.dart';
import '../../domain/models/food_restriction_mouse.dart';

class FoodRestrictionController extends ChangeNotifier {
  FoodRestrictionController(this._service);

  final FoodRestrictionService _service;

  List<FoodRestrictionExperiment> _experiments = const [];
  List<FoodRestrictionMouse> _mice = const [];
  List<FoodRestrictionEntry> _entries = const [];
  bool _isLoading = false;

  List<FoodRestrictionExperiment> get experiments => _experiments;
  List<FoodRestrictionMouse> get mice => _mice;
  List<FoodRestrictionEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final values = await Future.wait([
      _service.listExperiments(),
      _service.listExperimentMice(),
      _service.listEntries(),
    ]);
    _experiments = values[0] as List<FoodRestrictionExperiment>;
    _mice = values[1] as List<FoodRestrictionMouse>;
    _entries = values[2] as List<FoodRestrictionEntry>;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveExperiment(FoodRestrictionExperiment experiment) async {
    await _service.saveExperiment(experiment);
    await load();
  }

  Future<void> deleteExperiment(String experimentId) async {
    await _service.deleteExperiment(experimentId);
    await load();
  }

  Future<void> saveExperimentMouse(FoodRestrictionMouse mouse) async {
    await _service.saveExperimentMouse(mouse);
    await load();
  }

  Future<void> deleteExperimentMouse(String mouseId) async {
    await _service.deleteExperimentMouse(mouseId);
    await load();
  }

  Future<void> saveEntry(FoodRestrictionEntry entry) async {
    await _service.saveEntry(entry);
    final mouse = _mice.firstWhere((item) => item.id == entry.experimentMouseId);
    final mouseEntries = _service.entriesForMouse(mouse.id, [
      ..._entries.where((item) => item.id != entry.id),
      entry,
    ]);
    if (mouseEntries.isNotEmpty) {
      final baseline = mouseEntries.first.weightGrams;
      await _service.saveExperimentMouse(
        mouse.copyWith(
          baselineWeightGrams: baseline,
          updatedAt: DateTime.now(),
        ),
      );
    }
    await load();
  }

  Future<void> deleteEntry(String entryId) async {
    final existingEntry = _entries.firstWhere((item) => item.id == entryId);
    await _service.deleteEntry(entryId);
    final mouse = _mice.firstWhere((item) => item.id == existingEntry.experimentMouseId);
    final remainingEntries = _service.entriesForMouse(
      mouse.id,
      _entries.where((item) => item.id != entryId).toList(),
    );
    await _service.saveExperimentMouse(
      mouse.copyWith(
        baselineWeightGrams:
            remainingEntries.isEmpty ? null : remainingEntries.first.weightGrams,
        clearBaseline: remainingEntries.isEmpty,
        updatedAt: DateTime.now(),
      ),
    );
    await load();
  }

  List<FoodRestrictionMouse> miceForExperiment(String experimentId) =>
      _service.miceForExperiment(experimentId, _mice);

  List<FoodRestrictionEntry> entriesForMouse(String mouseId) =>
      _service.entriesForMouse(mouseId, _entries);

  List<ComputedFoodRestrictionEntry> computedEntriesForMouse(String mouseId) =>
      _service.computeTimeline(entriesForMouse(mouseId));

  double? baselineForMouse(FoodRestrictionMouse mouse) =>
      _service.baselineForMouse(mouse, _entries);

  Future<String> exportExperimentCsv(FoodRestrictionExperiment experiment) {
    return _service.exportExperimentCsv(
      experiment: experiment,
      mice: _mice,
      entries: _entries,
    );
  }

  Future<String> exportMouseCsv(
    FoodRestrictionExperiment experiment,
    FoodRestrictionMouse mouse,
  ) {
    return _service.exportMouseCsv(
      mouse: mouse,
      experiment: experiment,
      entries: _entries,
    );
  }

  Future<String> exportAllCsv() {
    return _service.exportAllCsv(
      experiments: _experiments,
      mice: _mice,
      entries: _entries,
    );
  }

  int get activeExperimentCount =>
      _experiments.where((experiment) => experiment.isActive).length;

  int get trackedMouseCount => _mice.length;

  int get lowWeightAlertCount {
    var count = 0;
    for (final mouse in _mice) {
      final computed = computedEntriesForMouse(mouse.id);
      if (computed.isNotEmpty && computed.last.percentOfOriginal < 80) {
        count += 1;
      }
    }
    return count;
  }
}
