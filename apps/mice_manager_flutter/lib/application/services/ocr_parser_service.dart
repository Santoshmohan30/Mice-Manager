import '../../core/constants/app_constants.dart';

class OCRParserService {
  const OCRParserService();

  Map<String, String> parseMouseFields(String rawText) {
    final cleaned = rawText.replaceAll('\r', '\n');
    return {
      'strain': _detectStrain(cleaned),
      'gender': _detectGender(cleaned),
      'genotype': _detectGenotype(cleaned),
      'dob': _detectDate(cleaned, label: 'dob'),
      'cage_number': _detectCage(cleaned),
      'rack_location': _detectRack(cleaned),
      'housing_type': _detectHousingType(cleaned),
    };
  }

  String _detectStrain(String text) {
    final upper = text.toUpperCase();
    const aliases = <String, String>{
      'CALB': 'Calb1-IRES-Cre',
      'CALB1': 'Calb1-IRES-Cre',
      'CALV1': 'Calb1-IRES-Cre',
      'CALV': 'Calb1-IRES-Cre',
      'IRSCRE': 'Calb1-IRES-Cre',
      'IRESCRE': 'Calb1-IRES-Cre',
      'TNNT': 'Tnnt1-IRES-CreERT2',
      'TNNT1': 'Tnnt1-IRES-CreERT2',
      'TNT': 'Tnnt1-IRES-CreERT2',
      'C1QL2': 'C1ql2-RES-Cre',
      'CIQL2': 'C1ql2-RES-Cre',
      'NPSR1': 'Npsr1-IRES-Flp',
      'FLP': 'Npsr1-IRES-Flp',
      'C57/BL': 'C57/BL',
      'C57BL': 'C57/BL',
      'C57 BL': 'C57/BL',
    };

    for (final entry in aliases.entries) {
      if (upper.contains(entry.key)) {
        return entry.value;
      }
    }
    return AppConstants.supportedStrains.first;
  }

  String _detectGender(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('FEMALE')) {
      return 'FEMALE';
    }
    if (upper.contains('MALE')) {
      return 'MALE';
    }
    return 'UNKNOWN';
  }

  String _detectGenotype(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('+ POSITIVE') || upper.contains('POSITIVE')) {
      return '+ positive';
    }
    if (upper.contains('- NEGATIVE') || upper.contains('NEGATIVE')) {
      return '- negative';
    }
    return '+ positive';
  }

  String _detectDate(String text, {required String label}) {
    final labelPatterns = <RegExp>[
      RegExp('$label\\s*[:\\-]?\\s*(\\d{1,2}/\\d{1,2}/\\d{2,4})',
          caseSensitive: false),
      RegExp('date\\s*of\\s*birth\\s*[:\\-]?\\s*(\\d{1,2}/\\d{1,2}/\\d{2,4})',
          caseSensitive: false),
      RegExp('received\\s*date\\s*[:\\-]?\\s*(\\d{1,2}/\\d{1,2}/\\d{2,4})',
          caseSensitive: false),
    ];
    for (final regex in labelPatterns) {
      final match = regex.firstMatch(text);
      if (match != null) {
        return _normalizeDate(match.group(1)!);
      }
    }

    final generalMatch = RegExp(r'(\d{1,2}/\d{1,2}/\d{2,4})').firstMatch(text);
    if (generalMatch != null) {
      return _normalizeDate(generalMatch.group(1)!);
    }
    return '';
  }

  String _detectCage(String text) {
    final matches =
        RegExp(r'\bCC\d+\b', caseSensitive: false).allMatches(text).toList();
    if (matches.isNotEmpty) {
      return matches.last.group(0)!.toUpperCase();
    }
    return '';
  }

  String _detectRack(String text) {
    final labeled = RegExp(r'RACK\s*[:\-]?\s*([A-Z]\d+)', caseSensitive: false)
        .firstMatch(text);
    if (labeled != null) {
      return labeled.group(1)!.toUpperCase();
    }
    final general = RegExp(r'\b[A-Z]\d+\b')
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList();
    if (general.isNotEmpty) {
      return general.last.toUpperCase();
    }
    return '';
  }

  String _detectHousingType(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('LAB')) {
      return 'LAB';
    }
    return 'LAF';
  }

  String _normalizeDate(String input) {
    final parts = input.split('/');
    if (parts.length != 3) {
      return input;
    }
    final month = parts[0].padLeft(2, '0');
    final day = parts[1].padLeft(2, '0');
    final yearPart = parts[2];
    final year = yearPart.length == 2 ? '20$yearPart' : yearPart;
    return '$month/$day/$year';
  }
}
