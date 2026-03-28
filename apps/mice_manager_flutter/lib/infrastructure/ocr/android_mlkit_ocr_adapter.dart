import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_adapter.dart';

class AndroidMlKitOCRAdapter implements OCRAdapter {
  AndroidMlKitOCRAdapter();

  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> extractRawText(String sourcePath) async {
    final inputImage = InputImage.fromFilePath(sourcePath);
    final result = await _recognizer.processImage(inputImage);
    return result.text;
  }

  Future<void> close() => _recognizer.close();
}
