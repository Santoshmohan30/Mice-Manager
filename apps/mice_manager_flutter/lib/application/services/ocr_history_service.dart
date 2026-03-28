import '../../domain/models/ocr_document.dart';
import '../../domain/repositories/ocr_document_repository.dart';

class OCRHistoryService {
  const OCRHistoryService(this._repository);

  final OCRDocumentRepository _repository;

  Future<List<OCRDocument>> listAll() => _repository.listAll();

  Future<List<OCRDocument>> listDeleted() => _repository.listDeleted();

  Future<void> save(OCRDocument document) => _repository.save(document);

  Future<void> archive(String documentId) => _repository.archive(documentId);

  Future<void> restore(String documentId) => _repository.restore(documentId);

  Future<int> archiveByCageNumber(String cageNumber) async {
    final normalized = cageNumber.trim().toUpperCase();
    if (normalized.isEmpty) {
      return 0;
    }
    final items = await _repository.listAll();
    final matches = items
        .where((item) =>
            (item.parsedFields['cage_number'] ?? '').trim().toUpperCase() ==
            normalized)
        .toList();
    for (final item in matches) {
      await _repository.archive(item.id);
    }
    return matches.length;
  }

  Future<int> restoreByCageNumber(String cageNumber) async {
    final normalized = cageNumber.trim().toUpperCase();
    if (normalized.isEmpty) {
      return 0;
    }
    final items = await _repository.listDeleted();
    final matches = items
        .where((item) =>
            (item.parsedFields['cage_number'] ?? '').trim().toUpperCase() ==
            normalized)
        .toList();
    for (final item in matches) {
      await _repository.restore(item.id);
    }
    return matches.length;
  }
}
