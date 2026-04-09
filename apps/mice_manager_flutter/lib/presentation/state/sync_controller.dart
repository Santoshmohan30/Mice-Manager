import 'package:flutter/foundation.dart';

import '../../application/services/sync_service.dart';
import '../../domain/models/breeding.dart';
import '../../domain/models/mouse.dart';
import '../../domain/models/ocr_document.dart';
import '../../domain/models/procedure.dart';
import '../../domain/models/sync_package.dart';

class SyncController extends ChangeNotifier {
  SyncController(this._service);

  final SyncService _service;

  List<SyncPackage> _packages = const [];
  bool _isLoading = false;
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isPreparingQr = false;
  String? _quickSyncPayload;
  bool _isExportingSheet = false;
  bool _isHostingLanHub = false;
  String? _lanHubUrl;
  String? _lanHubSummary;

  List<SyncPackage> get packages => _packages;
  bool get isLoading => _isLoading;
  bool get isExporting => _isExporting;
  bool get isImporting => _isImporting;
  bool get isPreparingQr => _isPreparingQr;
  String? get quickSyncPayload => _quickSyncPayload;
  bool get isExportingSheet => _isExportingSheet;
  bool get isHostingLanHub => _isHostingLanHub;
  String? get lanHubUrl => _lanHubUrl;
  String? get lanHubSummary => _lanHubSummary;
  bool isPendingReview(SyncPackage package) => _service.isPendingReview(package);
  bool isRejected(SyncPackage package) => _service.isRejected(package);

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _packages = await _service.listSyncPackages();
    _isLoading = false;
    notifyListeners();
  }

  Future<SyncPackage> createBundle({
    required List<Mouse> mice,
    required List<Breeding> breedings,
    required List<Procedure> procedures,
    required List<OCRDocument> ocrDocuments,
  }) async {
    _isExporting = true;
    notifyListeners();
    final result = await _service.publishSyncBundle(
      mice: mice,
      breedings: breedings,
      procedures: procedures,
      ocrDocuments: ocrDocuments,
    );
    _packages = await _service.listSyncPackages();
    _isExporting = false;
    notifyListeners();
    return result;
  }

  Future<SyncPackage> importBundle(String bundlePath) async {
    _isImporting = true;
    notifyListeners();
    final result = await _service.importBundleFromPath(bundlePath);
    _packages = await _service.listSyncPackages();
    _isImporting = false;
    notifyListeners();
    return result;
  }

  Future<String> prepareQuickSyncPayload({
    required List<Mouse> mice,
    required List<Breeding> breedings,
    required List<Procedure> procedures,
    required List<OCRDocument> ocrDocuments,
  }) async {
    _isPreparingQr = true;
    notifyListeners();
    final payload = await _service.buildQuickSyncPayload(
      mice: mice,
      breedings: breedings,
      procedures: procedures,
      ocrDocuments: ocrDocuments,
    );
    _quickSyncPayload = payload;
    _isPreparingQr = false;
    notifyListeners();
    return payload;
  }

  Future<SyncPackage> importQuickSyncPayload(String payload) async {
    _isImporting = true;
    notifyListeners();
    final result = await _service.importQuickSyncPayload(payload);
    _packages = await _service.listSyncPackages();
    _isImporting = false;
    notifyListeners();
    return result;
  }

  Future<SyncPackage> pushToLanHub({
    required String hubUrl,
    required List<Mouse> mice,
    required List<Breeding> breedings,
    required List<Procedure> procedures,
    required List<OCRDocument> ocrDocuments,
  }) async {
    _isImporting = true;
    notifyListeners();
    final result = await _service.pushToLanHub(
      hubUrl: hubUrl,
      mice: mice,
      breedings: breedings,
      procedures: procedures,
      ocrDocuments: ocrDocuments,
    );
    _packages = await _service.listSyncPackages();
    _isImporting = false;
    notifyListeners();
    return result;
  }

  Future<String> exportMiceCsv(List<Mouse> mice) async {
    _isExportingSheet = true;
    notifyListeners();
    final path = await _service.exportMiceCsv(mice);
    _isExportingSheet = false;
    notifyListeners();
    return path;
  }

  Future<String> exportMiceExcel(List<Mouse> mice) async {
    _isExportingSheet = true;
    notifyListeners();
    final path = await _service.exportMiceExcel(mice);
    _isExportingSheet = false;
    notifyListeners();
    return path;
  }

  Future<String> startLanHub({
    required List<Mouse> mice,
    required List<Breeding> breedings,
    required List<Procedure> procedures,
    required List<OCRDocument> ocrDocuments,
  }) async {
    _isHostingLanHub = true;
    notifyListeners();
    final session = await _service.startLanHub(
      mice: mice,
      breedings: breedings,
      procedures: procedures,
      ocrDocuments: ocrDocuments,
    );
    _lanHubUrl = session.url;
    _lanHubSummary = session.summary;
    _isHostingLanHub = false;
    notifyListeners();
    return session.url;
  }

  Future<void> stopLanHub() async {
    await _service.stopLanHub();
    _lanHubUrl = null;
    _lanHubSummary = null;
    notifyListeners();
  }

  Future<SyncPackage> approvePendingPackage(SyncPackage package) async {
    _isImporting = true;
    notifyListeners();
    final result = await _service.approvePendingPackage(package);
    _packages = await _service.listSyncPackages();
    _isImporting = false;
    notifyListeners();
    return result;
  }

  Future<SyncPackage> rejectPendingPackage(SyncPackage package) async {
    _isImporting = true;
    notifyListeners();
    final result = await _service.rejectPendingPackage(package);
    _packages = await _service.listSyncPackages();
    _isImporting = false;
    notifyListeners();
    return result;
  }
}
