import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/housing_type.dart';
import '../../domain/models/mouse.dart';
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
    }
  }
}

class DuplicateMouseException implements Exception {
  const DuplicateMouseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiceController extends ChangeNotifier {
  MiceController(this._mouseService);

  final MouseService _mouseService;

  List<Mouse> _mice = const [];
  bool _isLoading = false;
  HousingFilter _filter = HousingFilter.all;
  String _strainFilter = 'All strains';
  String _genderFilter = 'All genders';
  String _genotypeFilter = 'All genotypes';
  MouseAgeFilter _ageFilter = MouseAgeFilter.all;

  List<Mouse> get allMice => _mice;

  List<Mouse> get mice {
    return _mice.where((mouse) {
      final housingMatches = switch (_filter) {
        HousingFilter.laf => mouse.housingType == HousingType.laf,
        HousingFilter.lab => mouse.housingType == HousingType.lab,
        HousingFilter.all => true,
      };
      final strainMatches =
          _strainFilter == 'All strains' || mouse.strain == _strainFilter;
      final genderMatches =
          _genderFilter == 'All genders' || mouse.gender == _genderFilter;
      final genotypeMatches = _genotypeFilter == 'All genotypes' ||
          mouse.genotype == _genotypeFilter;
      final ageMatches = _matchesAgeFilter(mouse);
      return housingMatches &&
          strainMatches &&
          genderMatches &&
          genotypeMatches &&
          ageMatches;
    }).toList();
  }

  bool get isLoading => _isLoading;
  HousingFilter get filter => _filter;
  String get strainFilter => _strainFilter;
  String get genderFilter => _genderFilter;
  String get genotypeFilter => _genotypeFilter;
  MouseAgeFilter get ageFilter => _ageFilter;
  int get totalCount => _mice.length;
  int get lafCount =>
      _mice.where((mouse) => mouse.housingType == HousingType.laf).length;
  int get labCount =>
      _mice.where((mouse) => mouse.housingType == HousingType.lab).length;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _mice = await _mouseService.listAll();
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
    required String rackLocation,
    String? notes,
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
      rackLocation: rackLocation.trim(),
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

  Future<void> deleteMouse(String mouseId) async {
    await _mouseService.delete(mouseId);
    await load();
  }

  bool _matchesAgeFilter(Mouse mouse) {
    if (_ageFilter == MouseAgeFilter.all) {
      return true;
    }
    if (_ageFilter == MouseAgeFilter.aboveOneYear) {
      return mouse.ageInMonths >= 12;
    }
    final targetMonth = MouseAgeFilter.values.indexOf(_ageFilter);
    return mouse.ageInMonths == targetMonth;
  }
}
