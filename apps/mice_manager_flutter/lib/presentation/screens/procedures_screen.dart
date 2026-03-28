import 'package:flutter/material.dart';

import '../../domain/models/mouse.dart';
import '../../domain/models/procedure.dart';
import '../state/procedure_controller.dart';

class ProceduresScreen extends StatelessWidget {
  const ProceduresScreen({
    super.key,
    required this.controller,
    required this.mice,
  });

  final ProcedureController controller;
  final List<Mouse> mice;

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
          body: items.isEmpty
              ? const Center(
                  child: Text(
                      'No procedures yet. Tap Add Procedure to create one.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(
                          horizontal: -1,
                          vertical: -1,
                        ),
                        title: Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          '${_mouseLabel(item.mouseId)}\n${_formatDate(item.performedAt)}'
                          '${item.performedBy == null ? '' : '\nBy: ${item.performedBy}'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete procedure'),
                                content:
                                    const Text('Delete this procedure record?'),
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
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: mice.isEmpty
                ? null
                : () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => _AddProcedureSheet(
                        controller: controller,
                        mice: mice,
                      ),
                    );
                  },
            icon: const Icon(Icons.add),
            label: const Text('Add Procedure'),
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

class _AddProcedureSheet extends StatefulWidget {
  const _AddProcedureSheet({
    required this.controller,
    required this.mice,
  });

  final ProcedureController controller;
  final List<Mouse> mice;

  @override
  State<_AddProcedureSheet> createState() => _AddProcedureSheetState();
}

class _AddProcedureSheetState extends State<_AddProcedureSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dateController = TextEditingController(text: '03/27/2026');
  final _performedByController = TextEditingController();
  final _notesController = TextEditingController();
  String? _mouseId;

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _performedByController.dispose();
    _notesController.dispose();
    super.dispose();
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Procedure',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _mouseId,
                decoration: const InputDecoration(labelText: 'Mouse'),
                items: widget.mice
                    .map((mouse) => DropdownMenuItem(
                          value: mouse.id,
                          child: Text('${mouse.strain} (${mouse.cageNumber})'),
                        ))
                    .toList(),
                validator: (value) => value == null ? 'Required' : null,
                onChanged: (value) => setState(() => _mouseId = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Procedure name'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateController,
                decoration:
                    const InputDecoration(labelText: 'Performed (MM/DD/YYYY)'),
                validator: (value) =>
                    _parseDate(value) == null ? 'Enter a valid date' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _performedByController,
                decoration: const InputDecoration(labelText: 'Performed by'),
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
                    final performedAt = _parseDate(_dateController.text);
                    if (performedAt == null || _mouseId == null) {
                      return;
                    }
                    await widget.controller.save(
                      Procedure(
                        id: 'procedure-${DateTime.now().microsecondsSinceEpoch}',
                        mouseId: _mouseId!,
                        name: _nameController.text.trim(),
                        performedAt: performedAt,
                        performedBy: _performedByController.text.trim().isEmpty
                            ? null
                            : _performedByController.text.trim(),
                        notes: _notesController.text.trim().isEmpty
                            ? null
                            : _notesController.text.trim(),
                      ),
                    );
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save Procedure'),
                ),
              ),
            ],
          ),
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
