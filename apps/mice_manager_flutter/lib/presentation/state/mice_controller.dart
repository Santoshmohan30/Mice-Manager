import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/housing_type.dart';
import '../../domain/models/mouse.dart';
import '../../domain/models/mouse_archive_snapshot.dart';
import '../../application/services/mouse_service.dart';

enum HousingFilter {
  all,
  laf,
  lab,
}

enum MouseAgeFilter {
  all,
  month1,
  month2,
  month3,
  month4,
  month5,
  month6,
  month7,
  month8,
  month9,
  month10,
  month11,
  month12,
  aboveOneYear,
  aboveTwoYears,
}

extension MouseAgeFilterX on MouseAgeFilter {
  String get label {
    switch (this) {
      case MouseAgeFilter.all:
        return 'All ages';
      case MouseAgeFilter.month1:
        return '1 month old';
      case MouseAgeFilter.month2:
        return '2 month old';
      case MouseAgeFilter.month3:
        return '3 month old';
      case MouseAgeFilter.month4:
        return '4 month old';
      case MouseAgeFilter.month5:
        return '5 month old';
      case MouseAgeFilter.month6:
        return '6 month old';
      case MouseAgeFilter.month7:
        return '7 month old';
      case MouseAgeFilter.month8:
        return '8 month old';
      case MouseAgeFilter.month9:
        return '9 month old';
      case MouseAgeFilter.month10:
        return '10 month old';
      case MouseAgeFilter.month11:
        return '11 month old';
      case MouseAgeFilter.month12:
        return '12 month old';
      case MouseAgeFilter.aboveOneYear:
        return '1+ year old';
      case MouseAgeFilter.aboveTwoYears:
        return '2+ years old';
    }
  }
}

class DuplicateMouseException implements Exception {
  const DuplicateMouseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BulkMouseSaveResult {
  const BulkMouseSaveResult({
    required this.savedCount,
    required this.skippedCageNumbers,
  });

  final int savedCount;
  final List<String> skippedCageNumbers;
}

class MiceController extends ChangeNotifier {
  MiceController(this._mouseService);

  final MouseService _mouseService;

  List<Mouse> _mice = const [];
  List<MouseArchiveSnapshot> _archiveSnapshots = const [];
  bool _isLoading = false;
  HousingFilter _filter = HousingFilter.all;
  String _strainFilter = 'All strains';
  String _genderFilter = 'All genders';
  String _genotypeFilter = 'All genotypes';
  MouseAgeFilter _ageFilter = MouseAgeFilter.all;
  String _cageSearch = '';

  List<Mouse> get allMice => _mice;
  List<MouseArchiveSnapshot> get archiveSnapshots => _archiveSnapshots;
  List<MouseArchiveSnapshot> get activeArchiveSnapshots =>
      _archiveSnapshots.where((snapshot) => !snapshot.isRestored).toList();

  List<Mouse> _filteredMice({bool ignoreStrainFilter = false}) {
    return _mice.where((mouse) {
      final housingMatches = switch (_filter) {
        HousingFilter.laf => mouse.housingType == HousingType.laf,
        HousingFilter.lab => mouse.housingType == HousingType.lab,
        HousingFilter.all => true,
      };
      final strainMatches = ignoreStrainFilter ||
          _strainFilter == 'All strains' ||
          mouse.strain == _strainFilter;
      final genderMatches =
          _genderFilter == 'All genders' || mouse.gender == _genderFilter;
      final genotypeMatches = _genotypeFilter == 'All genotypes' ||
          mouse.genotype == _genotypeFilter;
      final ageMatches = _matchesAgeFilter(mouse);
      final query = _cageSearch.trim().toUpperCase();
      final searchMatches = query.isEmpty ||
          mouse.cageNumber.toUpperCase().contains(query) ||
          mouse.strain.toUpperCase().contains(query) ||
          mouse.gender.toUpperCase().contains(query) ||
          mouse.genotype.toUpperCase().contains(query) ||
          (mouse.rackNumber ?? '').toUpperCase().contains(query) ||
          (mouse.exactRackLocation ?? '').toUpperCase().contains(query) ||
          mouse.locationSummary.toUpperCase().contains(query);
      return housingMatches &&
          strainMatches &&
          genderMatches &&
          genotypeMatches &&
          ageMatches &&
          searchMatches;
    }).toList();
  }

  List<Mouse> get mice => _filteredMice();

  bool get isLoading => _isLoading;
  HousingFilter get filter => _filter;
  String get strainFilter => _strainFilter;
  String get genderFilter => _genderFilter;
  String get genotypeFilter => _genotypeFilter;
  MouseAgeFilter get ageFilter => _ageFilter;
  String get cageSearch => _cageSearch;
  int get totalCount => _mice.length;
  int get currentResultsCount => mice.length;
  int get lafCount =>
      _mice.where((mouse) => mouse.housingType == HousingType.laf).length;
  int get labCount =>
      _mice.where((mouse) => mouse.housingType == HousingType.lab).length;
  int? get selectedStrainTotal =>
      _strainFilter == 'All strains' ? null : mice.length;

  List<MapEntry<String, int>> get strainTotals {
    final totals = <String, int>{};
    for (final mouse in _filteredMice(ignoreStrainFilter: true)) {
      totals[mouse.strain] = (totals[mouse.strain] ?? 0) + 1;
    }
    final items = totals.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.key.compareTo(b.key);
      });
    return items;
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _mice = await _mouseService.listAll();
    _archiveSnapshots = await _mouseService.listArchiveSnapshots();
    _isLoading = false;
    notifyListeners();
  }

  void setFilter(HousingFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void setStrainFilter(String value) {
    _strainFilter = value;
    notifyListeners();
  }

  void setGenderFilter(String value) {
    _genderFilter = value;
    notifyListeners();
  }

  void setGenotypeFilter(String value) {
    _genotypeFilter = value;
    notifyListeners();
  }

  void setAgeFilter(MouseAgeFilter value) {
    _ageFilter = value;
    notifyListeners();
  }

  void setCageSearch(String value) {
    _cageSearch = value.trim();
    notifyListeners();
  }

  List<String> get availableStrains => [
        'All strains',
        ..._mice.map((mouse) => mouse.strain).toSet().toList()..sort(),
      ];

  List<String> get availableGenders => [
        'All genders',
        ..._mice.map((mouse) => mouse.gender).toSet().toList()..sort(),
      ];

  List<String> get availableGenotypes => [
        'All genotypes',
        ..._mice.map((mouse) => mouse.genotype).toSet().toList()..sort(),
      ];

  Future<void> addMouse({
    required HousingType housingType,
    required String strain,
    required String gender,
    required String genotype,
    required DateTime dateOfBirth,
    required String cageNumber,
    String? rackNumber,
    String? rowNumber,
    String? rackLocation,
    String? notes,
    bool hasCranialWindow = false,
    bool isImplanted = false,
    bool hasGreenLens = false,
  }) async {
    final now = DateTime.now();
    final mouse = Mouse(
      id: 'mouse-${now.microsecondsSinceEpoch}',
      housingType: housingType,
      strain: strain.trim(),
      gender: gender.trim().toUpperCase(),
      genotype: genotype.trim(),
      dateOfBirth: dateOfBirth,
      cageNumber: cageNumber.trim(),
      rackNumber:
          rackNumber?.trim().isEmpty ?? true ? null : rackNumber?.trim(),
      rowNumber: rowNumber?.trim().isEmpty ?? true ? null : rowNumber?.trim(),
      rackLocation:
          rackLocation?.trim().isEmpty ?? true ? null : rackLocation?.trim(),
      hasCranialWindow: hasCranialWindow,
      isImplanted: isImplanted,
      hasGreenLens: hasGreenLens,
      room: AppConstants.defaultRoom,
      isAlive: true,
      status: 'Active',
      notes: notes?.trim().isEmpty ?? true ? null : notes?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    if (await _mouseService.hasDuplicate(mouse)) {
      throw const DuplicateMouseException(
        'A mouse with the same cage, strain, gender, genotype, and DOB already exists.',
      );
    }
    await _mouseService.save(mouse);
    await load();
  }

  Future<void> updateMouse(Mouse mouse) async {
    final updated = mouse.copyWith(updatedAt: DateTime.now());
    if (await _mouseService.hasDuplicate(updated)) {
      throw const DuplicateMouseException(
        'Updating this record would create a duplicate mouse entry.',
      );
    }
    await _mouseService.save(updated);
    await load();
  }

  Future<void> markMouseGenotype(Mouse mouse, String genotype) async {
    await _mouseService.save(
      mouse.copyWith(
        genotype: genotype,
        updatedAt: DateTime.now(),
      ),
    );
    await load();
  }

  Future<void> deleteMouse(String mouseId, {String? archivedBy}) async {
    await _mouseService.delete(mouseId, archivedBy: archivedBy);
    await load();
  }

  Future<void> restoreSnapshot(
    MouseArchiveSnapshot snapshot, {
    String? restoredBy,
  }) async {
    await _mouseService.restoreArchiveSnapshot(
      snapshot,
      restoredBy: restoredBy,
    );
    await load();
  }

  Future<BulkMouseSaveResult> addReplicatedMice({
    required Mouse baseMouse,
    required List<String> cageNumbers,
  }) async {
    final normalized = <String>[];
    final seen = <String>{};
    final skipped = <String>[];

    for (final raw in cageNumbers) {
      final cage = AppConstants.normalizeCageCardNumber(raw);
      if (cage.isEmpty || !seen.add(cage)) {
        if (cage.isNotEmpty) {
          skipped.add(cage);
        }
        continue;
      }
      normalized.add(cage);
    }

    var savedCount = 0;
    for (var index = 0; index < normalized.length; index += 1) {
      final now = DateTime.now().add(Duration(microseconds: index));
      final candidate = baseMouse.copyWith(
        id: 'mouse-${now.microsecondsSinceEpoch}',
        cageNumber: normalized[index],
        createdAt: now,
        updatedAt: now,
      );
      if (await _mouseService.hasDuplicate(candidate)) {
        skipped.add(normalized[index]);
        continue;
      }
      await _mouseService.save(candidate);
      savedCount += 1;
    }

    await load();
    return BulkMouseSaveResult(
      savedCount: savedCount,
      skippedCageNumbers: skipped,
    );
  }

  bool _matchesAgeFilter(Mouse mouse) {
    if (_ageFilter == MouseAgeFilter.all) {
      return true;
    }
    if (_ageFilter == MouseAgeFilter.aboveOneYear) {
      return mouse.ageInMonths >= 12;
    }
    if (_ageFilter == MouseAgeFilter.aboveTwoYears) {
      return mouse.ageInMonths >= 24;
    }
    final targetMonth = MouseAgeFilter.values.indexOf(_ageFilter);
    return mouse.ageInMonths == targetMonth;
  }
}
