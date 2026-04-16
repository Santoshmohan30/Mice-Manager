import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/housing_type.dart';
import '../../domain/models/mouse.dart';
import 'bulk_mouse_replicate_sheet.dart';
import '../state/mice_controller.dart';

class MiceScreen extends StatefulWidget {
  const MiceScreen({
    super.key,
    required this.controller,
  });

  final MiceController controller;

  @override
  State<MiceScreen> createState() => _MiceScreenState();
}

class _MiceScreenState extends State<MiceScreen> {
  bool _showAdvancedSearch = false;

  bool get _hasAdvancedFilters =>
      widget.controller.strainFilter != 'All strains' ||
      widget.controller.genderFilter != 'All genders' ||
      widget.controller.genotypeFilter != 'All genotypes' ||
      widget.controller.ageFilter != MouseAgeFilter.all ||
      widget.controller.filter != HousingFilter.all;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final controller = widget.controller;
        final mice = controller.mice;
        return Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            label: 'Total',
                            value: controller.totalCount.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            label: 'LAF',
                            value: controller.lafCount.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            label: 'LAB',
                            value: controller.labCount.toString(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(controller.cageSearch),
                            initialValue: controller.cageSearch,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Search mice',
                              hintText: 'CC number, strain, rack, genotype',
                              isDense: true,
                              suffixIcon: controller.cageSearch.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        controller.setCageSearch('');
                                      },
                                      icon: const Icon(Icons.clear),
                                    ),
                            ),
                            onChanged: controller.setCageSearch,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          onPressed: () {
                            setState(
                              () => _showAdvancedSearch = !_showAdvancedSearch,
                            );
                          },
                          icon: Icon(
                            _showAdvancedSearch
                                ? Icons.expand_less
                                : Icons.tune,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text('${controller.currentResultsCount} mice'),
                        ),
                        if (controller.selectedStrainTotal != null)
                          Chip(
                            label: Text(
                              '${controller.strainFilter}: ${controller.selectedStrainTotal}',
                            ),
                          ),
                        if (_hasAdvancedFilters)
                          const Chip(label: Text('Advanced filters active')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 180),
                      crossFadeState: _showAdvancedSearch || _hasAdvancedFilters
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Column(
                        children: [
                          SegmentedButton<HousingFilter>(
                            segments: const [
                              ButtonSegment(
                                value: HousingFilter.all,
                                label: Text('All'),
                              ),
                              ButtonSegment(
                                value: HousingFilter.laf,
                                label: Text('LAF'),
                              ),
                              ButtonSegment(
                                value: HousingFilter.lab,
                                label: Text('LAB'),
                              ),
                            ],
                            selected: {controller.filter},
                            onSelectionChanged: (selection) {
                              controller.setFilter(selection.first);
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: controller.strainFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'Strain',
                                    isDense: true,
                                  ),
                                  items: controller.availableStrains
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(value),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      controller.setStrainFilter(value);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: controller.genderFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'Gender',
                                    isDense: true,
                                  ),
                                  items: controller.availableGenders
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(value),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      controller.setGenderFilter(value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: controller.genotypeFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'Genotype',
                                    isDense: true,
                                  ),
                                  items: controller.availableGenotypes
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(value),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      controller.setGenotypeFilter(value);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<MouseAgeFilter>(
                                  initialValue: controller.ageFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'Age',
                                    isDense: true,
                                  ),
                                  items: MouseAgeFilter.values
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(value.label),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      controller.setAgeFilter(value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                controller
                                  ..setFilter(HousingFilter.all)
                                  ..setStrainFilter('All strains')
                                  ..setGenderFilter('All genders')
                                  ..setGenotypeFilter('All genotypes')
                                  ..setAgeFilter(MouseAgeFilter.all)
                                  ..setCageSearch('');
                              },
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Reset filters'),
                            ),
                          ),
                        ],
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                    if (controller.strainTotals.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: controller.strainTotals
                              .take(8)
                              .map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ActionChip(
                                    label: Text('${entry.key} (${entry.value})'),
                                    onPressed: () {
                                      controller.setStrainFilter(entry.key);
                                      setState(() => _showAdvancedSearch = true);
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: mice.isEmpty
                    ? const Center(
                        child: Text(
                          'No mice yet. Tap Add Mouse to create the first record.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: mice.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final mouse = mice[index];
                          return _MouseCard(
                            mouse: mouse,
                            onEdit: () async {
                              await showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) => _MouseEditorSheet(
                                  controller: controller,
                                  existingMouse: mouse,
                                ),
                              );
                            },
                            onDelete: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete mouse'),
                                  content: Text(
                                    'Delete ${mouse.strain} in cage ${mouse.cageNumber}?',
                                  ),
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
                                await controller.deleteMouse(mouse.id);
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (context) =>
                    _MouseEditorSheet(controller: controller),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Mouse'),
          ),
        );
      },
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

class _MouseCard extends StatelessWidget {
  const _MouseCard({
    required this.mouse,
    required this.onEdit,
    required this.onDelete,
  });

  final Mouse mouse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    child: Icon(
                      Icons.pest_control_rodent,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      mouse.strain,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(
                        mouse.housingType == HousingType.laf ? 'LAF' : 'LAB'),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Cage: ${mouse.cageNumber}'),
              Text('Gender: ${mouse.gender}'),
              Text('Genotype: ${mouse.genotype}'),
              Text('DOB: ${_formatDate(mouse.dateOfBirth)}'),
              Text('Age: ${mouse.ageBucketLabel} (${mouse.ageInDays} days)'),
              Text('Location: ${mouse.locationSummary}'),
              Text('Room: ${mouse.room ?? '-'}'),
              if (mouse.procedureMarkers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: mouse.procedureMarkers
                      .map((marker) => Chip(label: Text(marker)))
                      .toList(),
                ),
              ],
              const SizedBox(height: 6),
              Text('Status: ${mouse.status}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _MouseEditorSheet extends StatefulWidget {
  const _MouseEditorSheet({
    required this.controller,
    this.existingMouse,
  });

  final MiceController controller;
  final Mouse? existingMouse;

  @override
  State<_MouseEditorSheet> createState() => _MouseEditorSheetState();
}

class _MouseEditorSheetState extends State<_MouseEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _strainController;
  late final TextEditingController _genotypeController;
  late final TextEditingController _dobController;
  late final TextEditingController _cageController;
  late final TextEditingController _rackNumberController;
  late final TextEditingController _rowController;
  late final TextEditingController _notesController;
  late HousingType _housingType;
  late String _selectedGender;
  late String _selectedGenotype;
  late bool _hasCranialWindow;
  late bool _isImplanted;
  late bool _hasGreenLens;
  bool _saving = false;

  bool get _isEditing => widget.existingMouse != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingMouse;
    _housingType = existing?.housingType ?? HousingType.laf;
    _selectedGender = existing?.gender ?? AppConstants.supportedGenders.first;
    _selectedGenotype =
        existing?.genotype ?? AppConstants.supportedGenotypes.first;
    _hasCranialWindow = existing?.hasCranialWindow ?? false;
    _isImplanted = existing?.isImplanted ?? false;
    _hasGreenLens = existing?.hasGreenLens ?? false;
    _strainController = TextEditingController(
      text: existing?.strain ?? AppConstants.supportedStrains.first,
    );
    _genotypeController = TextEditingController(text: _selectedGenotype);
    _dobController = TextEditingController(
      text: existing == null ? '03/01/2026' : _formatDate(existing.dateOfBirth),
    );
    _cageController = TextEditingController(
      text: existing == null
          ? ''
          : AppConstants.cageCardDigits(existing.cageNumber),
    );
    _rackNumberController =
        TextEditingController(text: existing?.rackNumber ?? '');
    _rowController = TextEditingController(
      text: existing?.exactRackLocation ?? '',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _strainController.dispose();
    _genotypeController.dispose();
    _dobController.dispose();
    _cageController.dispose();
    _rackNumberController.dispose();
    _rowController.dispose();
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
              Text(
                _isEditing ? 'Edit Mouse' : 'Add Mouse',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<HousingType>(
                initialValue: _housingType,
                decoration: const InputDecoration(labelText: 'Housing'),
                items: const [
                  DropdownMenuItem(value: HousingType.laf, child: Text('LAF')),
                  DropdownMenuItem(value: HousingType.lab, child: Text('LAB')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _housingType = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _strainController.text,
                decoration: const InputDecoration(labelText: 'Strain'),
                items: AppConstants.supportedStrains
                    .map(
                      (strain) => DropdownMenuItem(
                        value: strain,
                        child: Text(strain),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _strainController.text = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: AppConstants.supportedGenders
                    .map(
                      (gender) => DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedGender = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedGenotype,
                decoration: const InputDecoration(labelText: 'Genotype'),
                items: AppConstants.supportedGenotypes
                    .map(
                      (genotype) => DropdownMenuItem(
                        value: genotype,
                        child: Text(genotype),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedGenotype = value);
                    _genotypeController.text = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildField(
                _dobController,
                'DOB (MM/DD/YYYY)',
                validator: (value) =>
                    _parseDate(value) == null ? 'Enter a valid DOB' : null,
              ),
              const SizedBox(height: 12),
              _buildField(
                _cageController,
                'CC number',
                keyboardType: TextInputType.number,
                prefixText: 'CC',
                validator: (value) {
                  final text =
                      AppConstants.normalizeCageCardNumber(value ?? '');
                  if (text.isEmpty) {
                    return 'Required';
                  }
                  if (!text.toUpperCase().startsWith('CC')) {
                    return 'Cage should usually start with CC';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildField(_rackNumberController, 'Rack number'),
              const SizedBox(height: 12),
              _buildField(_rowController, 'Row / rack location'),
              const SizedBox(height: 6),
              Text(
                'Use Rack number like 3 and Row / rack location like 7E.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: AppConstants.defaultRoom,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Room'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Manual Procedure Marks',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Cranial Window'),
                    selected: _hasCranialWindow,
                    onSelected: (value) {
                      setState(() => _hasCranialWindow = value);
                    },
                  ),
                  FilterChip(
                    label: const Text('Implanted'),
                    selected: _isImplanted,
                    onSelected: (value) {
                      setState(() => _isImplanted = value);
                    },
                  ),
                  FilterChip(
                    label: const Text('Grin Lens'),
                    selected: _hasGreenLens,
                    onSelected: (value) {
                      setState(() => _hasGreenLens = value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving
                            ? 'Saving...'
                            : _isEditing
                                ? 'Update Mouse'
                                : 'Save Mouse',
                      ),
                    ),
                  ),
                  if (!_isEditing) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _openReplicateFlow,
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Replicate'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _buildField(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    String? prefixText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Required';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final dob = _parseDate(_dobController.text);
    if (dob == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        final existing = widget.existingMouse!;
        await widget.controller.updateMouse(
          existing.copyWith(
            housingType: _housingType,
            strain: _strainController.text.trim(),
            gender: _selectedGender,
            genotype: _selectedGenotype,
            dateOfBirth: dob,
            cageNumber:
                AppConstants.normalizeCageCardNumber(_cageController.text),
            rackNumber: _rackNumberController.text.trim(),
            rowNumber: _rowController.text.trim(),
            rackLocation: null,
            hasCranialWindow: _hasCranialWindow,
            isImplanted: _isImplanted,
            hasGreenLens: _hasGreenLens,
            room: AppConstants.defaultRoom,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          ),
        );
      } else {
        await widget.controller.addMouse(
          housingType: _housingType,
          strain: _strainController.text,
          gender: _selectedGender,
          genotype: _selectedGenotype,
          dateOfBirth: dob,
          cageNumber: AppConstants.normalizeCageCardNumber(_cageController.text),
          rackNumber: _rackNumberController.text,
          rowNumber: _rowController.text,
          rackLocation: null,
          notes: _notesController.text,
          hasCranialWindow: _hasCranialWindow,
          isImplanted: _isImplanted,
          hasGreenLens: _hasGreenLens,
        );
      }
    } on DuplicateMouseException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _openReplicateFlow() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final dob = _parseDate(_dobController.text);
    if (dob == null) {
      return;
    }

    final baseMouse = Mouse(
      id: 'draft-mouse',
      housingType: _housingType,
      strain: _strainController.text.trim(),
      gender: _selectedGender,
      genotype: _selectedGenotype,
      dateOfBirth: dob,
      cageNumber: AppConstants.normalizeCageCardNumber(_cageController.text),
      rackNumber: _rackNumberController.text.trim(),
      rowNumber: _rowController.text.trim(),
      rackLocation: null,
      hasCranialWindow: _hasCranialWindow,
      isImplanted: _isImplanted,
      hasGreenLens: _hasGreenLens,
      room: AppConstants.defaultRoom,
      isAlive: true,
      status: 'Active',
      notes:
          _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await showModalBottomSheet<BulkMouseSaveResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => BulkMouseReplicateSheet(
        controller: widget.controller,
        baseMouse: baseMouse,
        title: 'Replicate Mouse Records',
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    Navigator.of(context).pop();
    final skipped = result.skippedCageNumbers;
    final message = skipped.isEmpty
        ? 'Saved ${result.savedCount} mouse record(s).'
        : 'Saved ${result.savedCount} mouse record(s). Skipped: ${skipped.join(', ')}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
}

String _formatDate(DateTime value) {
  return '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year}';
}
