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

typedef InboundSyncAppliedCallback = Future<void> Function();

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
  InboundSyncAppliedCallback? _onInboundSyncApplied;

  void registerInboundSyncListener(InboundSyncAppliedCallback callback) {
    _onInboundSyncApplied = callback;
  }

  Future<String> _writePendingPayload(Map<String, dynamic> payload) async {
    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/pending-sync-${DateTime.now().microsecondsSinceEpoch}.json';
    await File(path)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return path;
  }

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
      if (request.uri.path == '/sync/latest' && request.method == 'GET') {
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
        return;
      }

      if (request.uri.path == '/sync/push' && request.method == 'POST') {
        final token = request.uri.queryParameters['token'];
        if (token != _hubToken) {
          request.response
            ..statusCode = HttpStatus.forbidden
            ..write('Invalid token');
          await request.response.close();
          return;
        }
        final body = await utf8.decoder.bind(request).join();
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        if (decoded['kind'] != 'mice_manager_device_push') {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..write('Invalid push payload');
          await request.response.close();
          return;
        }
        final pendingPath = await _writePendingPayload(decoded);
        final summary = await _previewPayload(decoded);
        final syncPackage = SyncPackage(
          id: 'hub-receive-${DateTime.now().microsecondsSinceEpoch}',
          version: decoded['version'] as String? ?? 'hub-receive',
          createdAt: DateTime.now(),
          deviceSourceId: decoded['device_source_id'] as String? ?? 'phone-push',
          bundlePath: pendingPath,
          notes: 'Pending review • $summary',
        );
        await _repository.saveSyncPackage(syncPackage);
        if (_onInboundSyncApplied != null) {
          await _onInboundSyncApplied!.call();
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'status': 'ok',
            'summary': summary,
            'version': syncPackage.version,
            'review_required': true,
          }),
        );
        await request.response.close();
        return;
      }

      if (request.method != 'GET' && request.method != 'POST') {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found');
        await request.response.close();
        return;
      }
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found');
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

  Future<SyncPackage> pushToLanHub({
    required String hubUrl,
    required List<Mouse> mice,
    required List<Breeding> breedings,
    required List<Procedure> procedures,
    required List<OCRDocument> ocrDocuments,
  }) async {
    final latestUri = Uri.parse(hubUrl);
    final pushUri = latestUri.replace(path: '/sync/push');
    final client = HttpClient();
    try {
      final request = await client.postUrl(pushUri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'kind': 'mice_manager_device_push',
        'version': 'push-${DateTime.now().millisecondsSinceEpoch}',
        'created_at': DateTime.now().toIso8601String(),
        'device_source_id': Platform.isAndroid ? 'android-phone' : 'desktop-device',
        'mice': mice.map((item) => item.toMap()).toList(),
        'breedings': breedings.map((item) => item.toMap()).toList(),
        'procedures': procedures.map((item) => item.toMap()).toList(),
        'ocr_documents': ocrDocuments.map((item) => item.toMap()).toList(),
      }));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        throw SyncException('Mac hub returned ${response.statusCode}.');
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final summary = decoded['summary'] as String? ??
          _buildSummary(
            mice: mice.length,
            breedings: breedings.length,
            procedures: procedures.length,
            ocrDocuments: ocrDocuments.length,
          );
      final syncPackage = SyncPackage(
        id: 'push-${DateTime.now().microsecondsSinceEpoch}',
        version: decoded['version'] as String? ?? 'phone-push',
        createdAt: DateTime.now(),
        deviceSourceId: Platform.isAndroid ? 'android-phone' : 'desktop-device',
        bundlePath: pushUri.toString(),
        notes: 'Uploaded to Mac hub • awaiting review • $summary',
      );
      await _repository.saveSyncPackage(syncPackage);
      return syncPackage;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _importPayload(Map<String, dynamic> payload) async {
    final existingMice = await _mouseRepository.listAll();
    final existingById = {
      for (final mouse in existingMice) mouse.id: mouse,
    };
    final existingSignatures = {
      for (final mouse in existingMice) _mouseSignature(mouse): mouse.id,
    };
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

    var createdMice = 0;
    var updatedMice = 0;
    var skippedDuplicateMice = 0;
    for (final mouse in mice) {
      final signature = _mouseSignature(mouse);
      final existingBySignatureId = existingSignatures[signature];
      if (existingBySignatureId != null && existingBySignatureId != mouse.id) {
        skippedDuplicateMice += 1;
        continue;
      }
      if (existingById.containsKey(mouse.id)) {
        updatedMice += 1;
      } else {
        createdMice += 1;
      }
      await _mouseRepository.save(mouse);
      existingById[mouse.id] = mouse;
      existingSignatures[signature] = mouse.id;
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
    return '${_buildSummary(
      mice: mice.length,
      breedings: breedings.length,
      procedures: procedures.length,
      ocrDocuments: ocrDocuments.length,
    )} • $createdMice new mice, $updatedMice updated, $skippedDuplicateMice duplicate skipped';
  }

  Future<String> _previewPayload(Map<String, dynamic> payload) async {
    final existingMice = await _mouseRepository.listAll();
    final existingById = {
      for (final mouse in existingMice) mouse.id: mouse,
    };
    final existingSignatures = {
      for (final mouse in existingMice) _mouseSignature(mouse): mouse.id,
    };
    final mice = (payload['mice'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((item) => Mouse.fromMap(item))
        .toList();
    final breedings = (payload['breedings'] as List<dynamic>? ?? const []);
    final procedures = (payload['procedures'] as List<dynamic>? ?? const []);
    final ocrDocuments = (payload['ocr_documents'] as List<dynamic>? ?? const []);

    var createdMice = 0;
    var updatedMice = 0;
    var skippedDuplicateMice = 0;
    for (final mouse in mice) {
      final signature = _mouseSignature(mouse);
      final existingBySignatureId = existingSignatures[signature];
      if (existingBySignatureId != null && existingBySignatureId != mouse.id) {
        skippedDuplicateMice += 1;
        continue;
      }
      if (existingById.containsKey(mouse.id)) {
        updatedMice += 1;
      } else {
        createdMice += 1;
      }
    }

    return '${_buildSummary(
      mice: mice.length,
      breedings: breedings.length,
      procedures: procedures.length,
      ocrDocuments: ocrDocuments.length,
    )} • $createdMice new mice, $updatedMice update candidate, $skippedDuplicateMice duplicate candidate';
  }

  bool isPendingReview(SyncPackage package) =>
      package.notes?.startsWith('Pending review') == true;

  bool isRejected(SyncPackage package) =>
      package.notes?.startsWith('Rejected') == true;

  Future<SyncPackage> approvePendingPackage(SyncPackage package) async {
    final file = File(package.bundlePath);
    final payload =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final summary = await _importPayload(payload);
    final approved = SyncPackage(
      id: package.id,
      version: package.version,
      createdAt: package.createdAt,
      deviceSourceId: package.deviceSourceId,
      bundlePath: package.bundlePath,
      notes: 'Approved import • $summary',
    );
    await _repository.saveSyncPackage(approved);
    if (_onInboundSyncApplied != null) {
      await _onInboundSyncApplied!.call();
    }
    return approved;
  }

  Future<SyncPackage> rejectPendingPackage(SyncPackage package) async {
    final rejected = SyncPackage(
      id: package.id,
      version: package.version,
      createdAt: package.createdAt,
      deviceSourceId: package.deviceSourceId,
      bundlePath: package.bundlePath,
      notes: 'Rejected • ${package.notes ?? ''}',
    );
    await _repository.saveSyncPackage(rejected);
    return rejected;
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

String _mouseSignature(Mouse mouse) {
  final year = mouse.dateOfBirth.year.toString().padLeft(4, '0');
  final month = mouse.dateOfBirth.month.toString().padLeft(2, '0');
  final day = mouse.dateOfBirth.day.toString().padLeft(2, '0');
  return [
    mouse.cageNumber.trim().toUpperCase(),
    mouse.strain.trim().toUpperCase(),
    mouse.gender.trim().toUpperCase(),
    mouse.genotype.trim().toUpperCase(),
    '$year-$month-$day',
  ].join('|');
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
