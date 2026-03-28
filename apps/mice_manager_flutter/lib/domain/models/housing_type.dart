enum HousingType {
  laf,
  lab,
}

extension HousingTypeX on HousingType {
  String get storageValue {
    switch (this) {
      case HousingType.laf:
        return 'LAF';
      case HousingType.lab:
        return 'LAB';
    }
  }
}

HousingType housingTypeFromStorage(String value) {
  switch (value.trim().toUpperCase()) {
    case 'LAF':
      return HousingType.laf;
    case 'LAB':
      return HousingType.lab;
    default:
      throw ArgumentError('Unsupported housing type: $value');
  }
}
