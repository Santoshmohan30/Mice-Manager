import 'package:flutter/material.dart';

import '../../domain/models/mouse.dart';
import '../state/mice_controller.dart';

class BulkMouseReplicateSheet extends StatefulWidget {
  const BulkMouseReplicateSheet({
    super.key,
    required this.controller,
    required this.baseMouse,
    this.title = 'Replicate Mice',
  });

  final MiceController controller;
  final Mouse baseMouse;
  final String title;

  @override
  State<BulkMouseReplicateSheet> createState() =>
      _BulkMouseReplicateSheetState();
}

class _BulkMouseReplicateSheetState extends State<BulkMouseReplicateSheet> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _cageControllers = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _seedRows(widget.baseMouse.cageNumber.trim().toUpperCase());
  }

  @override
  void dispose() {
    for (final controller in _cageControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _seedRows(String firstCage) {
    _cageControllers
      ..clear()
      ..addAll([
        TextEditingController(text: firstCage),
        TextEditingController(),
        TextEditingController(),
      ]);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Use one base mouse and save multiple cage card numbers at once. Shared fields stay the same.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _CommonFieldSummary(baseMouse: widget.baseMouse),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Cage card numbers',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Add row'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_cageControllers.length, _buildCageRow),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveAll,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save Replicated Mice'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCageRow(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _cageControllers[index],
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Cage card ${index + 1}',
                hintText: 'CC001234',
              ),
              validator: (value) {
                final text = value?.trim().toUpperCase() ?? '';
                if (text.isEmpty) {
                  return 'Required';
                }
                if (!text.startsWith('CC')) {
                  return 'Start with CC';
                }
                return null;
              },
            ),
          ),
          if (_cageControllers.length > 1) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: _saving ? null : () => _removeRow(index),
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ],
        ],
      ),
    );
  }

  void _addRow() {
    setState(() {
      _cageControllers.add(TextEditingController());
    });
  }

  void _removeRow(int index) {
    final controller = _cageControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    final result = await widget.controller.addReplicatedMice(
      baseMouse: widget.baseMouse,
      cageNumbers: _cageControllers.map((controller) => controller.text).toList(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _saving = false);
    Navigator.of(context).pop(result);
  }
}

class _CommonFieldSummary extends StatelessWidget {
  const _CommonFieldSummary({
    required this.baseMouse,
  });

  final Mouse baseMouse;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          runSpacing: 8,
          spacing: 16,
          children: [
            _SummaryChip(label: 'Strain', value: baseMouse.strain),
            _SummaryChip(label: 'Gender', value: baseMouse.gender),
            _SummaryChip(label: 'Genotype', value: baseMouse.genotype),
            _SummaryChip(
              label: 'DOB',
              value:
                  '${baseMouse.dateOfBirth.month.toString().padLeft(2, '0')}/${baseMouse.dateOfBirth.day.toString().padLeft(2, '0')}/${baseMouse.dateOfBirth.year}',
            ),
            _SummaryChip(
              label: 'Housing',
              value: baseMouse.housingType.name.toUpperCase(),
            ),
            _SummaryChip(
              label: 'Rack',
              value: baseMouse.locationSummary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
    );
  }
}
