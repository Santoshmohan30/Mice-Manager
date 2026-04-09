import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/food_restriction_entry.dart';
import '../../domain/models/food_restriction_experiment.dart';
import '../../domain/models/food_restriction_mouse.dart';
import '../../domain/repositories/food_restriction_repository.dart';

class DuplicateFoodRestrictionEntryException implements Exception {
  const DuplicateFoodRestrictionEntryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FoodRestrictionService {
  const FoodRestrictionService(this._repository);

  final FoodRestrictionRepository _repository;

  Future<List<FoodRestrictionExperiment>> listExperiments() =>
      _repository.listExperiments();

  Future<List<FoodRestrictionMouse>> listExperimentMice() =>
      _repository.listExperimentMice();

  Future<List<FoodRestrictionEntry>> listEntries() => _repository.listEntries();

  Future<void> saveExperiment(FoodRestrictionExperiment experiment) =>
      _repository.saveExperiment(experiment);

  Future<void> deleteExperiment(String experimentId) =>
      _repository.deleteExperiment(experimentId);

  Future<void> saveExperimentMouse(FoodRestrictionMouse mouse) =>
      _repository.saveExperimentMouse(mouse);

  Future<void> deleteExperimentMouse(String mouseId) =>
      _repository.deleteExperimentMouse(mouseId);

  Future<void> saveEntry(FoodRestrictionEntry entry) async {
    final entries = await _repository.listEntries();
    final normalizedDate = _dateKey(entry.entryDate);
    final duplicate = entries.any(
      (existing) =>
          existing.id != entry.id &&
          existing.experimentMouseId == entry.experimentMouseId &&
          _dateKey(existing.entryDate) == normalizedDate,
    );
    if (duplicate) {
      throw const DuplicateFoodRestrictionEntryException(
        'A daily tracking entry already exists for this mouse on that date.',
      );
    }
    await _repository.saveEntry(entry);
  }

  Future<void> deleteEntry(String entryId) => _repository.deleteEntry(entryId);

  List<FoodRestrictionMouse> miceForExperiment(
    String experimentId,
    List<FoodRestrictionMouse> mice,
  ) {
    final filtered =
        mice.where((mouse) => mouse.experimentId == experimentId).toList();
    filtered.sort((a, b) => a.serialNo.compareTo(b.serialNo));
    return filtered;
  }

  List<FoodRestrictionEntry> entriesForMouse(
    String mouseId,
    List<FoodRestrictionEntry> entries,
  ) {
    final filtered =
        entries.where((entry) => entry.experimentMouseId == mouseId).toList();
    filtered.sort((a, b) => a.entryDate.compareTo(b.entryDate));
    return filtered;
  }

  List<ComputedFoodRestrictionEntry> computeTimeline(
    List<FoodRestrictionEntry> entries,
  ) {
    if (entries.isEmpty) {
      return const [];
    }
    final sorted = [...entries]..sort((a, b) => a.entryDate.compareTo(b.entryDate));
    final baseline = sorted.first.weightGrams <= 0 ? 0.0 : sorted.first.weightGrams;
    var previous = 0.0;
    final computed = <ComputedFoodRestrictionEntry>[];
    for (var index = 0; index < sorted.length; index += 1) {
      final entry = sorted[index];
      final percentOfOriginal =
          baseline <= 0 ? 0.0 : (entry.weightGrams / baseline) * 100;
      final percentChange = index == 0 || previous <= 0
          ? null
          : ((entry.weightGrams - previous) / previous) * 100;
      computed.add(
        ComputedFoodRestrictionEntry(
          entry: entry,
          percentOfOriginal: percentOfOriginal,
          percentChange: percentChange,
          isBaseline: index == 0,
          isConcerning: percentOfOriginal < 80,
        ),
      );
      previous = entry.weightGrams;
    }
    return computed;
  }

  double? baselineForMouse(
    FoodRestrictionMouse mouse,
    List<FoodRestrictionEntry> entries,
  ) {
    final mouseEntries = entriesForMouse(mouse.id, entries);
    if (mouseEntries.isNotEmpty) {
      return mouseEntries.first.weightGrams;
    }
    return mouse.baselineWeightGrams;
  }

  bool isBelowThreshold(
    ComputedFoodRestrictionEntry entry,
    double threshold,
  ) {
    return entry.percentOfOriginal < threshold;
  }

  Future<String> exportExperimentCsv({
    required FoodRestrictionExperiment experiment,
    required List<FoodRestrictionMouse> mice,
    required List<FoodRestrictionEntry> entries,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/food-restriction-${_safeSlug(experiment.name)}-${DateTime.now().millisecondsSinceEpoch}.csv';
    final rows = <List<String>>[
      [
        'experiment',
        'mouse_name',
        'serial_no',
        'mouse_type',
        'group',
        'gender',
        'baseline_weight_g',
        'date',
        'person_performing',
        'weight_g',
        'percent_of_original',
        'percent_change',
        'food_weight_g',
        'condition',
        'notes',
      ],
    ];

    for (final mouse in miceForExperiment(experiment.id, mice)) {
      final computed = computeTimeline(entriesForMouse(mouse.id, entries));
      if (computed.isEmpty) {
        rows.add([
          experiment.name,
          mouse.mouseName,
          mouse.serialNo,
          mouse.mouseType,
          mouse.groupName,
          mouse.gender,
          _formatDouble(mouse.baselineWeightGrams),
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          mouse.notes ?? '',
        ]);
        continue;
      }
      for (final item in computed) {
        rows.add([
          experiment.name,
          mouse.mouseName,
          mouse.serialNo,
          mouse.mouseType,
          mouse.groupName,
          mouse.gender,
          _formatDouble(item.isBaseline
              ? item.entry.weightGrams
              : mouse.baselineWeightGrams ?? computed.first.entry.weightGrams),
          _dateKey(item.entry.entryDate),
          item.entry.personPerforming,
          _formatDouble(item.entry.weightGrams),
          item.percentOfOriginal.toStringAsFixed(2),
          item.percentChange?.toStringAsFixed(2) ?? '',
          _formatDouble(item.entry.foodWeightGrams),
          item.entry.conditionLabel ?? '',
          item.entry.notes ?? '',
        ]);
      }
    }

    await File(path).writeAsString(rows.map((row) => row.map(_csvEscape).join(',')).join('\n'));
    return path;
  }

  Future<String> exportMouseCsv({
    required FoodRestrictionMouse mouse,
    required FoodRestrictionExperiment experiment,
    required List<FoodRestrictionEntry> entries,
  }) {
    return exportExperimentCsv(
      experiment: experiment,
      mice: [mouse],
      entries: entriesForMouse(mouse.id, entries),
    );
  }

  Future<String> exportAllCsv({
    required List<FoodRestrictionExperiment> experiments,
    required List<FoodRestrictionMouse> mice,
    required List<FoodRestrictionEntry> entries,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/food-restriction-all-${DateTime.now().millisecondsSinceEpoch}.csv';
    final rows = <List<String>>[
      [
        'experiment',
        'mouse_name',
        'serial_no',
        'mouse_type',
        'group',
        'gender',
        'baseline_weight_g',
        'date',
        'person_performing',
        'weight_g',
        'percent_of_original',
        'percent_change',
        'food_weight_g',
        'condition',
        'notes',
      ],
    ];
    for (final experiment in experiments) {
      final experimentMice = miceForExperiment(experiment.id, mice);
      for (final mouse in experimentMice) {
        final computed = computeTimeline(entriesForMouse(mouse.id, entries));
        for (final item in computed) {
          rows.add([
            experiment.name,
            mouse.mouseName,
            mouse.serialNo,
            mouse.mouseType,
            mouse.groupName,
            mouse.gender,
            _formatDouble(computed.first.entry.weightGrams),
            _dateKey(item.entry.entryDate),
            item.entry.personPerforming,
            _formatDouble(item.entry.weightGrams),
            item.percentOfOriginal.toStringAsFixed(2),
            item.percentChange?.toStringAsFixed(2) ?? '',
            _formatDouble(item.entry.foodWeightGrams),
            item.entry.conditionLabel ?? '',
            item.entry.notes ?? '',
          ]);
        }
      }
    }
    await File(path).writeAsString(rows.map((row) => row.map(_csvEscape).join(',')).join('\n'));
    return path;
  }

  String _safeSlug(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _formatDouble(double? value) {
    if (value == null) {
      return '';
    }
    return value.toStringAsFixed(2);
  }
}
