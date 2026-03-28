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
}
