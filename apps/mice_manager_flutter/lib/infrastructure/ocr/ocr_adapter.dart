abstract class OCRAdapter {
  Future<String> extractRawText(String sourcePath);
}

abstract class ParsedOCRAdapter {
  Future<Map<String, String>> parseFields(String rawText);
}

// TODO(android-ocr): Integrate offline on-device OCR for Android.
// TODO(macos-ocr): Integrate local OCR engine for macOS.
