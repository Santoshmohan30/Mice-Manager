import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/breeding.dart';
import '../../domain/models/housing_type.dart';
import '../../domain/models/mouse.dart';
import '../../domain/models/ocr_document.dart';
import '../../domain/models/procedure.dart';
import '../../domain/models/sync_package.dart';
import '../../domain/repositories/breeding_repository.dart';
import '../../domain/repositories/mouse_repository.dart';
import '../../domain/repositories/ocr_document_repository.dart';
import '../../domain/repositories/procedure_repository.dart';
import '../../domain/repositories/sync_repository.dart';

class SyncService {
  SyncService(
    this._repository,
    this._mouseRepository,
    this._breedingRepository,
    this._procedureRepository,
    this._ocrDocumentRepository,
  );

  final SyncRepository _repository;
  final MouseRepository _mouseRepository;
  final BreedingRepository _breedingRepository;
  final ProcedureRepository _procedureRepository;
  final OCRDocumentRepository _ocrDocumentRepository;
  static const int _maxQuickSyncPayloadChars = 2200;
  HttpServer? _hubServer;
  String? _hubToken;
  String? _hubPayload;

  Future<SyncPackage> publishSyncBundle({
    required List<Mouse> mice,
    required List<Breeding> breedings,
    required List<Procedure> procedures,
    required List<OCRDocument> ocrDocuments,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now();
    final id = 'bundle-${timestamp.microsecondsSinceEpoch}';
    final version = 'v${timestamp.millisecondsSinceEpoch}';
    final path = '${directory.path}/$id.json';
    final file = File(path);
    final payload = {
      'version': version,
      'created_at': timestamp.toIso8601String(),
      'mice': mice.map((item) => item.toMap()).toList(),
      'breedings': breedings.map((item) => item.toMap()).toList(),
      'procedures': procedures.map((item) => item.toMap()).toList(),
      'ocr_documents': ocrDocuments.map((item) => item.toMap()).toList(),
    };
    await file
        .writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    final summary = _buildSummary(
      mice: mice.length,
      breedings: breedings.length,
      procedures: procedures.length,
      ocrDocuments: ocrDocuments.length,
    );
    final syncPackage = SyncPackage(
      id: id,
      version: version,
      createdAt: timestamp,
      deviceSourceId: 'android-local',
      bundlePath: path,
      notes: 'Local export bundle • $summary',
    );
    await _repository.saveSyncPackage(syncPackage);
    return syncPackage;
  }

  Future<String> exportMiceCsv(List<Mouse> mice) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now();
    final path =
        '${directory.path}/mice-export-${timestamp.millisecondsSinceEpoch}.csv';
    final file = File(path);
    final rows = <List<String>>[
      [
        'id',
        'housing_type',
        'strain',
        'gender',
        'genotype',
        'date_of_birth',
        'age_bucket',
        'age_days',
        'cage_number',
        'rack_location',
        'room',
        'is_alive',
        'status',
        'notes',
      ],
      ...mice.map(
        (mouse) => [
          mouse.id,
          mouse.housingType.storageValue,
          mouse.strain,
          mouse.gender,
          mouse.genotype,
          mouse.dateOfBirth.toIso8601String(),
          mouse.ageBucketLabel,
          mouse.ageInDays.toString(),
          mouse.cageNumber,
          mouse.rackLocation ?? '',
          mouse.room ?? '',
          mouse.isAlive ? 'true' : 'false',
          mouse.status,
          mouse.notes ?? '',
        ],
      ),
    ];
    final csv = rows.map((row) => row.map(_csvEscape).join(',')).join('\n');
    await file.writeAsString(csv);
    return path;
  }

  Future<String> buildQuickSyncPayload({
    required List<Mouse> mice,
    required List<Breeding> breedings,
    required List<Procedure> procedures,
    required List<OCRDocument> ocrDocuments,
  }) async {
    final timestamp = DateTime.now();
    final payload = jsonEncode({
      'kind': 'mice_manager_quick_sync',
      'version': 'v${timestamp.millisecondsSinceEpoch}',
      'created_at': timestamp.toIso8601String(),
      'mice': mice.map((item) => item.toMap()).toList(),
      'breedings': breedings.map((item) => item.toMap()).toList(),
      'procedures': procedures.map((item) => item.toMap()).toList(),
      'ocr_documents': ocrDocuments.map((item) => item.toMap()).toList(),
    });
    if (payload.length > _maxQuickSyncPayloadChars) {
      throw const SyncException(
        'This sync set is too large for a single QR. Use Create Export Bundle instead.',
      );
    }
    return payload;
  }

  Future<LanHubSession> startLanHub({
    required List<Mouse> mice,
    required List<Breeding> breedings,
    required List<Procedure> procedures,
    required List<OCRDocument> ocrDocuments,
  }) async {
    await stopLanHub();
    final timestamp = DateTime.now();
    _hubToken = 'hub-${timestamp.microsecondsSinceEpoch}';
    _hubPayload = jsonEncode({
      'kind': 'mice_manager_hub_sync',
      'version': 'hub-${timestamp.millisecondsSinceEpoch}',
      'created_at': timestamp.toIso8601String(),
      'mice': mice.map((item) => item.toMap()).toList(),
      'breedings': breedings.map((item) => item.toMap()).toList(),
      'procedures': procedures.map((item) => item.toMap()).toList(),
      'ocr_documents': ocrDocuments.map((item) => item.toMap()).toList(),
    });
    _hubServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _hubServer!.listen((request) async {
      if (request.method != 'GET' || request.uri.path != '/sync/latest') {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found');
        await request.response.close();
        return;
      }
      final token = request.uri.queryParameters['token'];
      if (token != _hubToken) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..write('Invalid token');
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(_hubPayload);
      await request.response.close();
    });

    final ip = await _resolveLocalIpv4Address();
    if (ip == null) {
      throw const SyncException(
        'Could not find a local Wi‑Fi IP for the Mac hub.',
      );
    }
    final url =
        'http://$ip:${_hubServer!.port}/sync/latest?token=${Uri.encodeQueryComponent(_hubToken!)}';
    return LanHubSession(
      url: url,
      summary: _buildSummary(
        mice: mice.length,
        breedings: breedings.length,
        procedures: procedures.length,
        ocrDocuments: ocrDocuments.length,
      ),
      port: _hubServer!.port,
    );
  }

  Future<void> stopLanHub() async {
    await _hubServer?.close(force: true);
    _hubServer = null;
    _hubToken = null;
    _hubPayload = null;
  }

  Future<List<SyncPackage>> listSyncPackages() =>
      _repository.listSyncPackages();

  Future<SyncPackage> importBundleFromPath(String bundlePath) async {
    final file = File(bundlePath);
    final payload =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final summary = await _importPayload(payload);

    final syncPackage = SyncPackage(
      id: 'import-${DateTime.now().microsecondsSinceEpoch}',
      version: payload['version'] as String? ?? 'imported',
      createdAt: DateTime.now(),
      deviceSourceId: 'external-import',
      bundlePath: bundlePath,
      notes: 'Imported into local storage • $summary',
    );
    await _repository.saveSyncPackage(syncPackage);
    return syncPackage;
  }

  Future<SyncPackage> importQuickSyncPayload(String payload) async {
    if (payload.startsWith('http://') || payload.startsWith('https://')) {
      return importFromLanUrl(payload);
    }
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    if (decoded['kind'] != 'mice_manager_quick_sync') {
      throw const SyncException(
          'That QR code is not a Mice Manager sync code.');
    }
    final summary = await _importPayload(decoded);
    final syncPackage = SyncPackage(
      id: 'qr-import-${DateTime.now().microsecondsSinceEpoch}',
      version: decoded['version'] as String? ?? 'qr-import',
      createdAt: DateTime.now(),
      deviceSourceId: 'quick-sync-qr',
      bundlePath: 'qr://quick-sync',
      notes: 'Imported from QR quick sync • $summary',
    );
    await _repository.saveSyncPackage(syncPackage);
    return syncPackage;
  }

  Future<SyncPackage> importFromLanUrl(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw SyncException('Hub returned ${response.statusCode}.');
      }
      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if (decoded['kind'] != 'mice_manager_hub_sync') {
        throw const SyncException(
          'That hub response is not a Mice Manager sync payload.',
        );
      }
      final summary = await _importPayload(decoded);
      final syncPackage = SyncPackage(
        id: 'lan-import-${DateTime.now().microsecondsSinceEpoch}',
        version: decoded['version'] as String? ?? 'lan-import',
        createdAt: DateTime.now(),
        deviceSourceId: 'lan-hub',
        bundlePath: url,
        notes: 'Imported from Mac hub • $summary',
      );
      await _repository.saveSyncPackage(syncPackage);
      return syncPackage;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _importPayload(Map<String, dynamic> payload) async {
    final mice = (payload['mice'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((item) => Mouse.fromMap(item))
        .toList();
    final breedings = (payload['breedings'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((item) => Breeding.fromMap(item))
        .toList();
    final procedures = (payload['procedures'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((item) => Procedure.fromMap(item))
        .toList();
    final ocrDocuments =
        (payload['ocr_documents'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map((item) => OCRDocument.fromMap(item))
            .toList();

    for (final mouse in mice) {
      await _mouseRepository.save(mouse);
    }
    for (final breeding in breedings) {
      await _breedingRepository.save(breeding);
    }
    for (final procedure in procedures) {
      await _procedureRepository.save(procedure);
    }
    for (final document in ocrDocuments) {
      await _ocrDocumentRepository.save(document);
    }
    return _buildSummary(
      mice: mice.length,
      breedings: breedings.length,
      procedures: procedures.length,
      ocrDocuments: ocrDocuments.length,
    );
  }

  Future<void> publishUpdateManifest() async {}

  Future<void> requestAndroidUpdateConfirmation() async {}
}

Future<String?> _resolveLocalIpv4Address() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (!address.isLoopback) {
        return address.address;
      }
    }
  }
  return null;
}

class LanHubSession {
  const LanHubSession({
    required this.url,
    required this.summary,
    required this.port,
  });

  final String url;
  final String summary;
  final int port;
}

String _buildSummary({
  required int mice,
  required int breedings,
  required int procedures,
  required int ocrDocuments,
}) {
  return '$mice mice, $breedings breedings, $procedures procedures, $ocrDocuments scans';
}

class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _csvEscape(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
