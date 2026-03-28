import 'package:flutter/material.dart';

import '../../domain/models/breeding.dart';
import '../../domain/models/mouse.dart';
import '../state/breeding_controller.dart';

class BreedingScreen extends StatelessWidget {
  const BreedingScreen({
    super.key,
    required this.controller,
    required this.mice,
    required this.onChanged,
  });

  final BreedingController controller;
  final List<Mouse> mice;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = controller.items;
        return Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Total pairs',
                        value: controller.totalCount.toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Active',
                        value: controller.activeCount.toString(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                            'No breeding pairs yet. Tap Add Pair to begin.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _BreedingCard(
                            breeding: item,
                            maleLabel: _mouseLabel(item.maleMouseId),
                            femaleLabel: _mouseLabel(item.femaleMouseId),
                            onDelete: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete breeding pair'),
                                  content: const Text(
                                      'Delete this breeding record?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await controller.delete(item.id);
                                await onChanged();
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: mice.length < 2
                ? null
                : () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => _AddBreedingSheet(
                        controller: controller,
                        mice: mice,
                        onChanged: onChanged,
                      ),
                    );
                  },
            icon: const Icon(Icons.add),
            label: const Text('Add Pair'),
          ),
        );
      },
    );
  }

  String _mouseLabel(String mouseId) {
    for (final mouse in mice) {
      if (mouse.id == mouseId) {
        return '${mouse.strain} (${mouse.cageNumber})';
      }
    }
    return mouseId;
  }
}

class _BreedingCard extends StatelessWidget {
  const _BreedingCard({
    required this.breeding,
    required this.maleLabel,
    required this.femaleLabel,
    required this.onDelete,
  });

  final Breeding breeding;
  final String maleLabel;
  final String femaleLabel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('$maleLabel x $femaleLabel'),
        subtitle: Text(
          'Started: ${_formatDate(breeding.startedAt)}'
          '${breeding.endedAt == null ? '\nStatus: Active' : '\nEnded: ${_formatDate(breeding.endedAt!)}'}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _AddBreedingSheet extends StatefulWidget {
  const _AddBreedingSheet({
    required this.controller,
    required this.mice,
    required this.onChanged,
  });

  final BreedingController controller;
  final List<Mouse> mice;
  final Future<void> Function() onChanged;

  @override
  State<_AddBreedingSheet> createState() => _AddBreedingSheetState();
}

class _AddBreedingSheetState extends State<_AddBreedingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _startedAtController = TextEditingController(text: '03/27/2026');
  final _notesController = TextEditingController();
  String? _maleMouseId;
  String? _femaleMouseId;

  @override
  void dispose() {
    _startedAtController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maleOptions =
        widget.mice.where((mouse) => mouse.gender == 'MALE').toList();
    final femaleOptions =
        widget.mice.where((mouse) => mouse.gender == 'FEMALE').toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Breeding Pair',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _maleMouseId,
                decoration: const InputDecoration(labelText: 'Male mouse'),
                items: maleOptions
                    .map((mouse) => DropdownMenuItem(
                          value: mouse.id,
                          child: Text('${mouse.strain} (${mouse.cageNumber})'),
                        ))
                    .toList(),
                validator: (value) => value == null ? 'Required' : null,
                onChanged: (value) => setState(() => _maleMouseId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _femaleMouseId,
                decoration: const InputDecoration(labelText: 'Female mouse'),
                items: femaleOptions
                    .map((mouse) => DropdownMenuItem(
                          value: mouse.id,
                          child: Text('${mouse.strain} (${mouse.cageNumber})'),
                        ))
                    .toList(),
                validator: (value) => value == null ? 'Required' : null,
                onChanged: (value) => setState(() => _femaleMouseId = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _startedAtController,
                decoration:
                    const InputDecoration(labelText: 'Started (MM/DD/YYYY)'),
                validator: (value) =>
                    _parseDate(value) == null ? 'Enter a valid date' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }
                    final startedAt = _parseDate(_startedAtController.text);
                    if (startedAt == null ||
                        _maleMouseId == null ||
                        _femaleMouseId == null) {
                      return;
                    }
                    await widget.controller.save(
                      Breeding(
                        id: 'breeding-${DateTime.now().microsecondsSinceEpoch}',
                        maleMouseId: _maleMouseId!,
                        femaleMouseId: _femaleMouseId!,
                        startedAt: startedAt,
                        notes: _notesController.text.trim().isEmpty
                            ? null
                            : _notesController.text.trim(),
                      ),
                    );
                    await widget.onChanged();
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save Pair'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}

DateTime? _parseDate(String? input) {
  if (input == null) {
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

String _formatDate(DateTime value) {
  return '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year}';
}
