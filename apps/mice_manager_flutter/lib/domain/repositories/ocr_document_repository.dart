import '../models/ocr_document.dart';

abstract class OCRDocumentRepository {
  Future<List<OCRDocument>> listAll();
  Future<List<OCRDocument>> listDeleted();
  Future<void> save(OCRDocument document);
  Future<void> archive(String documentId);
  Future<void> restore(String documentId);
}
