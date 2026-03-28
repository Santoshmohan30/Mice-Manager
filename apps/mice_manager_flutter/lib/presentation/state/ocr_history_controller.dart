import 'package:flutter/foundation.dart';

import '../../application/services/ocr_history_service.dart';
import '../../domain/models/ocr_document.dart';

class OCRHistoryController extends ChangeNotifier {
  OCRHistoryController(this._service);

  final OCRHistoryService _service;

  List<OCRDocument> _items = const [];
  List<OCRDocument> _deletedItems = const [];
  bool _isLoading = false;

  List<OCRDocument> get items => _items;
  List<OCRDocument> get deletedItems => _deletedItems;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _items = await _service.listAll();
    _deletedItems = await _service.listDeleted();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> save(OCRDocument document) async {
    await _service.save(document);
    await load();
  }

  Future<void> archive(String documentId) async {
    await _service.archive(documentId);
    await load();
  }

  Future<void> restore(String documentId) async {
    await _service.restore(documentId);
    await load();
  }

  Future<int> archiveByCageNumber(String cageNumber) async {
    final count = await _service.archiveByCageNumber(cageNumber);
    await load();
    return count;
  }

  Future<int> restoreByCageNumber(String cageNumber) async {
    final count = await _service.restoreByCageNumber(cageNumber);
    await load();
    return count;
  }
}
