import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/services/ocr_parser_service.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/models/ocr_document.dart';
import '../../domain/models/housing_type.dart';
import '../../infrastructure/ocr/android_mlkit_ocr_adapter.dart';
import '../state/ocr_history_controller.dart';
import '../state/mice_controller.dart';

class OCRIntakeScreen extends StatefulWidget {
  const OCRIntakeScreen({
    super.key,
    required this.controller,
    required this.historyController,
    required this.ocrAdapter,
    required this.parserService,
  });

  final MiceController controller;
  final OCRHistoryController historyController;
  final AndroidMlKitOCRAdapter ocrAdapter;
  final OCRParserService parserService;

  @override
  State<OCRIntakeScreen> createState() => _OCRIntakeScreenState();
}

class _OCRIntakeScreenState extends State<OCRIntakeScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _cageCardActionController =
      TextEditingController();

  XFile? _selectedImage;
  bool _isProcessing = false;
  String _rawText = '';
  Map<String, String> _fields = <String, String>{};
  bool _isEditing = false;

  @override
  void dispose() {
    _cageCardActionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline OCR Intake',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Pick a cage card image, review the parsed fields, then save the mouse into local storage.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take Photo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose Image'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(_selectedImage!.path),
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          if (_isProcessing) ...[
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Expanded(
                        child: Text(
                            'Running on-device OCR and parsing fields...')),
                  ],
                ),
              ),
            ),
          ],
          if (_fields.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Review Scanned Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() => _isEditing = !_isEditing);
                },
                child: Text(_isEditing ? 'Lock Review' : 'Edit Fields'),
              ),
            ),
            _FieldEditor(
              label: 'Strain',
              value: _fields['strain'] ?? '',
              enabled: _isEditing,
              onChanged: (value) => _updateField('strain', value),
            ),
            _FieldEditor(
              label: 'Gender',
              value: _fields['gender'] ?? '',
              enabled: _isEditing,
              onChanged: (value) => _updateField('gender', value),
            ),
            _FieldEditor(
              label: 'Genotype',
              value: _fields['genotype'] ?? '',
              enabled: _isEditing,
              onChanged: (value) => _updateField('genotype', value),
            ),
            _FieldEditor(
              label: 'DOB',
              value: _fields['dob'] ?? '',
              enabled: _isEditing,
              onChanged: (value) => _updateField('dob', value),
            ),
            _FieldEditor(
              label: 'Cage',
              value: _fields['cage_number'] ?? '',
              enabled: _isEditing,
              onChanged: (value) => _updateField('cage_number', value),
            ),
            _FieldEditor(
              label: 'Rack',
              value: _fields['rack_location'] ?? '',
              enabled: _isEditing,
              onChanged: (value) => _updateField('rack_location', value),
            ),
            _FieldEditor(
              label: 'Housing',
              value: _fields['housing_type'] ?? '',
              enabled: _isEditing,
              onChanged: (value) => _updateField('housing_type', value),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saveParsedMouse,
                child: const Text('Save as Mouse'),
              ),
            ),
          ],
          if (_rawText.isNotEmpty) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Raw OCR Text'),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(_rawText),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: widget.historyController,
            builder: (context, _) {
              final history = widget.historyController.items.take(5).toList();
              final archived =
                  widget.historyController.deletedItems.take(5).toList();
              if (history.isEmpty && archived.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _CageCardNumberActions(
                      controller: _cageCardActionController,
                      onArchive: _archiveByCageNumber,
                      onRestore: _restoreByCageNumber,
                    ),
                  ),
                );
              }
              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Recent OCR History'),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _CageCardNumberActions(
                          controller: _cageCardActionController,
                          onArchive: _archiveByCageNumber,
                          onRestore: _restoreByCageNumber,
                        ),
                      ),
                    ),
                  ),
                  ...history.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(item.parsedFields['strain'] ?? 'OCR Scan'),
                        subtitle: Text(
                          '${item.reviewStatus}\n${item.capturedAt.toLocal()}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await widget.historyController.archive(item.id);
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Cage card archived. You can restore it below.'),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (archived.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Archived cage cards',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    ...archived.map(
                      (item) => Card(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: ListTile(
                          title:
                              Text(item.parsedFields['strain'] ?? 'OCR Scan'),
                          subtitle: Text(
                            'Archived\n${item.deletedAt?.toLocal() ?? ''}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.restore),
                            onPressed: () async {
                              await widget.historyController.restore(item.id);
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cage card restored.'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _archiveByCageNumber() async {
    final cageNumber = _cageCardActionController.text.trim();
    final count =
        await widget.historyController.archiveByCageNumber(cageNumber);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'No cage card found for $cageNumber.'
              : 'Archived $count cage card(s) for $cageNumber.',
        ),
      ),
    );
  }

  Future<void> _restoreByCageNumber() async {
    final cageNumber = _cageCardActionController.text.trim();
    final count =
        await widget.historyController.restoreByCageNumber(cageNumber);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'No archived cage card found for $cageNumber.'
              : 'Restored $count cage card(s) for $cageNumber.',
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) {
      return;
    }

    setState(() {
      _selectedImage = file;
      _isProcessing = true;
      _rawText = '';
      _fields = <String, String>{};
      _isEditing = false;
    });

    try {
      final rawText = await widget.ocrAdapter.extractRawText(file.path);
      final fields = widget.parserService.parseMouseFields(rawText);
      if (!mounted) {
        return;
      }
      setState(() {
        _rawText = rawText;
        _fields = fields;
        _isProcessing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR failed: $error')),
      );
    }
  }

  Future<void> _saveParsedMouse() async {
    final dob = _parseDate(_fields['dob']);
    final cage = (_fields['cage_number'] ?? '').trim();
    if (dob == null || cage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('OCR result needs a valid DOB and cage number.')),
      );
      return;
    }

    await widget.controller.addMouse(
      housingType: (_fields['housing_type'] ?? 'LAF') == 'LAB'
          ? HousingType.lab
          : HousingType.laf,
      strain: _fields['strain'] ?? AppConstants.supportedStrains.first,
      gender: _fields['gender'] ?? 'UNKNOWN',
      genotype: _fields['genotype']?.trim().isNotEmpty == true
          ? _fields['genotype']!
          : AppConstants.supportedGenotypes.first,
      dateOfBirth: dob,
      cageNumber: cage,
      rackLocation: (_fields['rack_location'] ?? '').isEmpty
          ? 'Unassigned'
          : _fields['rack_location']!,
      notes: _rawText.isEmpty ? null : 'OCR import\n$_rawText',
    );
    await widget.historyController.save(
      OCRDocument(
        id: 'ocr-${DateTime.now().microsecondsSinceEpoch}',
        deviceId: 'android-local',
        sourcePath: _selectedImage?.path ?? '',
        rawText: _rawText,
        parsedFields: _fields,
        imageMetadata: {
          'source': _selectedImage == null ? 'unknown' : 'image_picker',
        },
        reviewStatus: _isEditing ? 'reviewed-edited' : 'reviewed',
        capturedAt: DateTime.now(),
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mouse saved from OCR intake.')),
    );
  }

  void _updateField(String key, String value) {
    setState(() {
      _fields = Map<String, String>.from(_fields)..[key] = value;
    });
  }

  DateTime? _parseDate(String? input) {
    if (input == null || input.trim().isEmpty) {
      return null;
    }
    final parts = input.trim().split('/');
    if (parts.length != 3) {
      return null;
    }
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) {
      return null;
    }
    return DateTime.tryParse(
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
    );
  }
}

class _CageCardNumberActions extends StatelessWidget {
  const _CageCardNumberActions({
    required this.controller,
    required this.onArchive,
    required this.onRestore,
  });

  final TextEditingController controller;
  final Future<void> Function() onArchive;
  final Future<void> Function() onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delete or recover by cage card number',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Type the cage card number, like CC001234, to archive it or restore it later.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Cage card number',
            hintText: 'CC001234',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onArchive,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Archive by Cage No.'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.restore),
                label: const Text('Restore by Cage No.'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldEditor extends StatelessWidget {
  const _FieldEditor({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          initialValue: value,
          enabled: enabled,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            helperText: value.isEmpty && !enabled ? 'Not found' : null,
          ),
        ),
      ),
    );
  }
}
