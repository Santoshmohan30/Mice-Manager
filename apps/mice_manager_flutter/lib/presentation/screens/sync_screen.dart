import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/models/sync_package.dart';
import '../state/breeding_controller.dart';
import '../state/mice_controller.dart';
import '../state/ocr_history_controller.dart';
import '../state/procedure_controller.dart';
import '../state/sync_controller.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({
    super.key,
    required this.controller,
    required this.miceController,
    required this.breedingController,
    required this.procedureController,
    required this.ocrHistoryController,
  });

  final SyncController controller;
  final MiceController miceController;
  final BreedingController breedingController;
  final ProcedureController procedureController;
  final OCRHistoryController ocrHistoryController;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  late final TextEditingController _importPathController;
  String? _quickSyncPayload;

  @override
  void initState() {
    super.initState();
    _importPathController = TextEditingController();
  }

  @override
  void dispose() {
    _importPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final packages = widget.controller.packages;
        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Local Sync Bundles',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Built by Sonny',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      if (!kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.macOS) ...[
                        FilledButton.icon(
                          onPressed: widget.controller.isHostingLanHub
                              ? null
                              : () async {
                                  try {
                                    final url =
                                        await widget.controller.startLanHub(
                                      mice: widget.miceController.allMice,
                                      breedings:
                                          widget.breedingController.items,
                                      procedures:
                                          widget.procedureController.items,
                                      ocrDocuments:
                                          widget.ocrHistoryController.items,
                                    );
                                    if (!context.mounted) {
                                      return;
                                    }
                                    setState(() => _quickSyncPayload = url);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Mac Wi‑Fi hub started: $url',
                                        ),
                                      ),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(error.toString()),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.wifi_tethering),
                          label: Text(
                            widget.controller.isHostingLanHub
                                ? 'Starting Mac Hub...'
                                : 'Start Mac Wi‑Fi Hub',
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.controller.lanHubUrl != null)
                          OutlinedButton.icon(
                            onPressed: () async {
                              await widget.controller.stopLanHub();
                              if (!mounted) {
                                return;
                              }
                              setState(() => _quickSyncPayload = null);
                            },
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('Stop Mac Hub'),
                          ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: widget.controller.isExporting
                            ? null
                            : () async {
                                final result =
                                    await widget.controller.createBundle(
                                  mice: widget.miceController.allMice,
                                  breedings: widget.breedingController.items,
                                  procedures: widget.procedureController.items,
                                  ocrDocuments:
                                      widget.ocrHistoryController.items,
                                );
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Bundle created: ${result.bundlePath}')),
                                );
                              },
                        child: Text(
                          widget.controller.isExporting
                              ? 'Creating Bundle...'
                              : 'Create Export Bundle',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: widget.controller.isExportingCsv
                            ? null
                            : () async {
                                final path = await widget.controller
                                    .exportMiceCsv(
                                        widget.miceController.allMice);
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('CSV exported: $path'),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.table_view_outlined),
                        label: Text(
                          widget.controller.isExportingCsv
                              ? 'Exporting CSV...'
                              : 'Export Mice CSV',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _importPathController,
                        decoration: const InputDecoration(
                          labelText: 'Import bundle path',
                          hintText: '/path/to/bundle.json',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: widget.controller.isImporting
                            ? null
                            : () async {
                                final result =
                                    await widget.controller.importBundle(
                                  _importPathController.text.trim(),
                                );
                                await Future.wait([
                                  widget.miceController.load(),
                                  widget.breedingController.load(),
                                  widget.procedureController.load(),
                                  widget.ocrHistoryController.load(),
                                ]);
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Bundle imported: ${result.bundlePath}')),
                                );
                              },
                        child: Text(
                          widget.controller.isImporting
                              ? 'Importing...'
                              : 'Import Bundle from Path',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: widget.controller.isPreparingQr
                            ? null
                            : () async {
                                try {
                                  final payload = await widget.controller
                                      .prepareQuickSyncPayload(
                                    mice: widget.miceController.allMice,
                                    breedings: widget.breedingController.items,
                                    procedures:
                                        widget.procedureController.items,
                                    ocrDocuments:
                                        widget.ocrHistoryController.items,
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  setState(() => _quickSyncPayload = payload);
                                } catch (error) {
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              },
                        icon: const Icon(Icons.qr_code_2),
                        label: Text(
                          widget.controller.isPreparingQr
                              ? 'Preparing QR...'
                              : 'Create Quick Sync QR',
                        ),
                      ),
                      if (defaultTargetPlatform == TargetPlatform.android) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: widget.controller.isImporting
                              ? null
                              : _scanQuickSyncQr,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan Quick Sync QR'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_quickSyncPayload != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Sync QR',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        if (widget.controller.lanHubSummary != null) ...[
                          const SizedBox(height: 10),
                          Text(widget.controller.lanHubSummary!),
                        ],
                        const SizedBox(height: 16),
                        Center(
                          child: QrImageView(
                            data: _quickSyncPayload!,
                            version: QrVersions.auto,
                            size: 240,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (packages.isEmpty)
                const Text('No sync bundles yet.')
              else
                ...packages.map(
                  (package) => _SyncPackageCard(
                    package: package,
                    controller: widget.controller,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scanQuickSyncQr() async {
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _QuickSyncScannerScreen(),
      ),
    );
    if (payload == null || payload.isEmpty || !mounted) {
      return;
    }
    try {
      final result = payload.startsWith('http://') || payload.startsWith('https://')
          ? await widget.controller.pushToLanHub(
              hubUrl: payload,
              mice: widget.miceController.allMice,
              breedings: widget.breedingController.items,
              procedures: widget.procedureController.items,
              ocrDocuments: widget.ocrHistoryController.items,
            )
          : await widget.controller.importQuickSyncPayload(payload);
      await Future.wait([
        widget.miceController.load(),
        widget.breedingController.load(),
        widget.procedureController.load(),
        widget.ocrHistoryController.load(),
      ]);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${payload.startsWith('http://') || payload.startsWith('https://') ? 'Phone data sent to Mac hub' : 'Quick sync imported'}: ${result.version}${result.notes == null ? '' : '\n${result.notes}'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

class _SyncPackageCard extends StatelessWidget {
  const _SyncPackageCard({
    required this.package,
    required this.controller,
  });

  final SyncPackage package;
  final SyncController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(package.version),
        subtitle: Text(
          'Source: ${package.deviceSourceId}\nCreated: ${package.createdAt.toLocal()}\nPath: ${package.bundlePath}${package.notes == null ? '' : '\n${package.notes}'}',
        ),
        isThreeLine: true,
        trailing: controller.isPendingReview(package)
            ? Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: controller.isImporting
                        ? null
                        : () async {
                            await controller.rejectPendingPackage(package);
                          },
                    child: const Text('Reject'),
                  ),
                  FilledButton.tonal(
                    onPressed: controller.isImporting
                        ? null
                        : () async {
                            await controller.approvePendingPackage(package);
                          },
                    child: const Text('Approve'),
                  ),
                ],
              )
            : controller.isRejected(package)
                ? const Chip(label: Text('Rejected'))
                : null,
      ),
    );
  }
}

class _QuickSyncScannerScreen extends StatefulWidget {
  const _QuickSyncScannerScreen();

  @override
  State<_QuickSyncScannerScreen> createState() =>
      _QuickSyncScannerScreenState();
}

class _QuickSyncScannerScreenState extends State<_QuickSyncScannerScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Quick Sync QR')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) {
            return;
          }
          final value = capture.barcodes.first.rawValue;
          if (value == null || value.isEmpty) {
            return;
          }
          _handled = true;
          Navigator.of(context).pop(value);
        },
      ),
    );
  }
}
