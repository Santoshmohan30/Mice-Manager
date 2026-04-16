class AppConstants {
  static const String productName = 'Mice Manager';
  static const String protocolNumber = '202300048';
  static const String defaultRoom = 'B2126 JSMBS';
  static const String ownerRecoveryPlaceholder = 'TODO-RECOVERY-KEY';
  static const int mouseGestationDays = 19;
  static const int mouseWeaningDaysAfterBirth = 21;
  static const List<String> supportedStrains = [
    'Calb1-IRES-Cre',
    'Tnnt1-IRES-CreERT2',
    'C1ql2-RES-Cre',
    'Npsr1-IRES-Flp',
    'C57/BL',
  ];
  static const List<String> supportedGenders = [
    'MALE',
    'FEMALE',
    'UNKNOWN',
  ];
  static const List<String> supportedGenotypes = [
    'Not sure',
    'Positive',
    'Negative',
  ];

  static String normalizeCageCardNumber(String raw) {
    final normalized = raw.trim().toUpperCase();
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.startsWith('CC')) {
      return normalized;
    }
    final numericOnly = RegExp(r'^\d+$');
    if (numericOnly.hasMatch(normalized)) {
      return 'CC$normalized';
    }
    return normalized;
  }

  static String cageCardDigits(String raw) {
    final normalized = raw.trim().toUpperCase();
    if (normalized.startsWith('CC')) {
      return normalized.substring(2);
    }
    return normalized;
  }
}
