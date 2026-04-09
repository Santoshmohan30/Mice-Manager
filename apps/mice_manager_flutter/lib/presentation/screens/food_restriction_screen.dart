import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/services/food_restriction_service.dart';
import '../../domain/models/food_restriction_entry.dart';
import '../../domain/models/food_restriction_experiment.dart';
import '../../domain/models/food_restriction_mouse.dart';
import '../state/food_restriction_controller.dart';

class FoodRestrictionScreen extends StatelessWidget {
  const FoodRestrictionScreen({
    super.key,
    required this.controller,
  });

  final FoodRestrictionController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final experiments = controller.experiments;
        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Food Restriction',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _TopStat(
                              title: 'Active Experiments',
                              value: controller.activeExperimentCount.toString(),
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TopStat(
                              title: 'Tracked Mice',
                              value: controller.trackedMouseCount.toString(),
                              color: const Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TopStat(
                              title: 'Low Weight Alerts',
                              value: controller.lowWeightAlertCount.toString(),
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
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
                      onPressed: () => _openExperimentEditor(context),
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Add Experiment'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final path = await controller.exportAllCsv();
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Full CSV exported to $path')),
                        );
                      },
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Export All CSV'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (experiments.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No food restriction experiments yet. Add one to start daily weight and food tracking.',
                    ),
                  ),
                ),
              ...experiments.map(
                (experiment) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExperimentCard(
                    experiment: experiment,
                    miceCount: controller.miceForExperiment(experiment.id).length,
                    latestAlertCount: controller
                        .miceForExperiment(experiment.id)
                        .where((mouse) {
                          final items = controller.computedEntriesForMouse(mouse.id);
                          return items.isNotEmpty &&
                              items.last.percentOfOriginal < 80;
                        })
                        .length,
                    onOpen: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _ExperimentDetailScreen(
                            controller: controller,
                            experimentId: experiment.id,
                          ),
                        ),
                      );
                      if (!context.mounted) {
                        return;
                      }
                      await controller.load();
                    },
                    onEdit: () => _openExperimentEditor(context, existing: experiment),
                    onDelete: () => _deleteExperiment(context, experiment),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openExperimentEditor(
    BuildContext context, {
    FoodRestrictionExperiment? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExperimentEditorSheet(
        controller: controller,
        existing: existing,
      ),
    );
  }

  Future<void> _deleteExperiment(
    BuildContext context,
    FoodRestrictionExperiment experiment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete experiment'),
        content: Text('Delete ${experiment.name} and all tracking data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteExperiment(experiment.id);
    }
  }
}

class _ExperimentDetailScreen extends StatelessWidget {
  const _ExperimentDetailScreen({
    required this.controller,
    required this.experimentId,
  });

  final FoodRestrictionController controller;
  final String experimentId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final experiment = controller.experiments.firstWhere(
          (item) => item.id == experimentId,
        );
        final mice = controller.miceForExperiment(experimentId);
        return Scaffold(
          appBar: AppBar(
            title: Text(experiment.name),
            actions: [
              IconButton(
                tooltip: 'Export experiment CSV',
                onPressed: () async {
                  final path = await controller.exportExperimentCsv(experiment);
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Experiment CSV exported to $path')),
                  );
                },
                icon: const Icon(Icons.download_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        experiment.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if ((experiment.description ?? '').isNotEmpty)
                        Text(experiment.description!),
                      const SizedBox(height: 8),
                      Text(
                        'Started ${_formatDate(experiment.startedAt)}${experiment.endedAt == null ? '' : ' • Ended ${_formatDate(experiment.endedAt!)}'}',
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
                      onPressed: () => _openMouseEditor(context, experiment),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Mouse'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (mice.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No mice added to this experiment yet.'),
                  ),
                ),
              ...mice.map(
                (mouse) {
                  final computed = controller.computedEntriesForMouse(mouse.id);
                  final latest = computed.isEmpty ? null : computed.last;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text('${mouse.mouseName} • ${mouse.serialNo}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              '${mouse.mouseType} • ${mouse.groupName} • ${mouse.gender}',
                            ),
                            Text(
                              latest == null
                                  ? 'No tracking entries yet'
                                  : 'Latest ${latest.entry.weightGrams.toStringAsFixed(1)} g • ${latest.percentOfOriginal.toStringAsFixed(1)}% of baseline',
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'open') {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _FoodRestrictionMouseDetailScreen(
                                    controller: controller,
                                    experiment: experiment,
                                    mouseId: mouse.id,
                                  ),
                                ),
                              );
                              if (!context.mounted) {
                                return;
                              }
                              await controller.load();
                            } else if (value == 'edit') {
                              _openMouseEditor(context, experiment, existing: mouse);
                            } else if (value == 'delete') {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete mouse'),
                                  content: Text(
                                    'Delete ${mouse.mouseName} and all tracking history?',
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
                                await controller.deleteExperimentMouse(mouse.id);
                              }
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'open', child: Text('Open')),
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openMouseEditor(
    BuildContext context,
    FoodRestrictionExperiment experiment, {
    FoodRestrictionMouse? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExperimentMouseEditorSheet(
        controller: controller,
        experiment: experiment,
        existing: existing,
      ),
    );
  }
}

class _FoodRestrictionMouseDetailScreen extends StatelessWidget {
  const _FoodRestrictionMouseDetailScreen({
    required this.controller,
    required this.experiment,
    required this.mouseId,
  });

  final FoodRestrictionController controller;
  final FoodRestrictionExperiment experiment;
  final String mouseId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final mouse = controller.mice.firstWhere((item) => item.id == mouseId);
        final computedEntries = controller.computedEntriesForMouse(mouseId);
        final baseline = controller.baselineForMouse(mouse);
        final latest = computedEntries.isEmpty ? null : computedEntries.last;

        return Scaffold(
          appBar: AppBar(
            title: Text(mouse.mouseName),
            actions: [
              IconButton(
                tooltip: 'Export mouse CSV',
                onPressed: () async {
                  final path = await controller.exportMouseCsv(experiment, mouse);
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Mouse CSV exported to $path')),
                  );
                },
                icon: const Icon(Icons.download_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${mouse.mouseName} • ${mouse.serialNo}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip('Type', mouse.mouseType),
                          _InfoChip('Group', mouse.groupName),
                          _InfoChip('Gender', mouse.gender),
                          _InfoChip(
                            'Baseline',
                            baseline == null
                                ? 'No entry yet'
                                : '${baseline.toStringAsFixed(1)} g',
                          ),
                          _InfoChip(
                            'Latest',
                            latest == null
                                ? 'No entry'
                                : '${latest.entry.weightGrams.toStringAsFixed(1)} g',
                          ),
                        ],
                      ),
                      if ((mouse.notes ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(mouse.notes!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _AnalyticsSummaryRow(
                latest: latest,
                entryCount: computedEntries.length,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weight Trend',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 260,
                        child: computedEntries.isEmpty
                            ? const Center(
                                child: Text('Add entries to see the trend chart.'),
                              )
                            : _FoodRestrictionTrendChart(entries: computedEntries),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: FilledButton.icon(
                      onPressed: () => _openEntryEditor(context, mouse),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Daily Entry'),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: OutlinedButton.icon(
                      onPressed: () => _openEntryEditor(
                        context,
                        mouse,
                        prefillFrom:
                            computedEntries.isEmpty ? null : computedEntries.last.entry,
                      ),
                      icon: const Icon(Icons.playlist_add_outlined),
                      label: const Text('Quick Next Day'),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _DailyTrackerSheetScreen(
                              controller: controller,
                              mouse: mouse,
                            ),
                          ),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        await controller.load();
                      },
                      icon: const Icon(Icons.table_rows_outlined),
                      label: const Text('Daily Tracker Sheet'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tracking History',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (computedEntries.isEmpty)
                        const Text('No daily entries yet.')
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 900) {
                              return _MobileTrackingHistory(
                                items: computedEntries,
                                onEdit: (entry) => _openEntryEditor(
                                  context,
                                  mouse,
                                  existing: entry,
                                ),
                                onDelete: (entry) => _deleteEntry(context, entry),
                              );
                            }
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Person')),
                                  DataColumn(label: Text('Weight')),
                                  DataColumn(label: Text('% Original')),
                                  DataColumn(label: Text('% Change')),
                                  DataColumn(label: Text('Food')),
                                  DataColumn(label: Text('Condition')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: computedEntries.map((item) {
                                  final percentOriginal =
                                      item.percentOfOriginal.toStringAsFixed(1);
                                  final percentChange = item.percentChange == null
                                      ? '--'
                                      : '${item.percentChange!.toStringAsFixed(1)}%';
                                  return DataRow(
                                    color: WidgetStateProperty.resolveWith<Color?>(
                                      (_) => item.percentOfOriginal < 80
                                          ? const Color(0xFFFFE4E6)
                                          : null,
                                    ),
                                    cells: [
                                      DataCell(Text(_formatDate(item.entry.entryDate))),
                                      DataCell(Text(item.entry.personPerforming)),
                                      DataCell(
                                        Text('${item.entry.weightGrams.toStringAsFixed(1)} g'),
                                      ),
                                      DataCell(Text('$percentOriginal%')),
                                      DataCell(Text(percentChange)),
                                      DataCell(Text(
                                        item.entry.foodWeightGrams == null
                                            ? '--'
                                            : '${item.entry.foodWeightGrams!.toStringAsFixed(1)} g',
                                      )),
                                      DataCell(Text(item.entry.conditionLabel ?? '--')),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined),
                                              onPressed: () => _openEntryEditor(
                                                context,
                                                mouse,
                                                existing: item.entry,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline),
                                              onPressed: () => _deleteEntry(
                                                context,
                                                item.entry,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEntryEditor(
    BuildContext context,
    FoodRestrictionMouse mouse, {
    FoodRestrictionEntry? existing,
    FoodRestrictionEntry? prefillFrom,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FoodRestrictionEntryEditorSheet(
        controller: controller,
        mouse: mouse,
        existing: existing,
        prefillFrom: prefillFrom,
      ),
    );
  }

  Future<void> _deleteEntry(
    BuildContext context,
    FoodRestrictionEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete daily entry'),
        content: Text('Delete the ${_formatDate(entry.entryDate)} entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteEntry(entry.id);
    }
  }
}

class _MobileTrackingHistory extends StatelessWidget {
  const _MobileTrackingHistory({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ComputedFoodRestrictionEntry> items;
  final ValueChanged<FoodRestrictionEntry> onEdit;
  final ValueChanged<FoodRestrictionEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        final percentChange = item.percentChange == null
            ? '0.00%'
            : '${item.percentChange!.toStringAsFixed(2)}%';
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: item.percentOfOriginal < 80
              ? const Color(0xFFFFF1F2)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDate(item.entry.entryDate),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEdit(item.entry),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onDelete(item.entry),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip('Person', item.entry.personPerforming),
                    _InfoChip(
                      'Weight',
                      '${item.entry.weightGrams.toStringAsFixed(1)} g',
                    ),
                    _InfoChip(
                      '% Original',
                      '${item.percentOfOriginal.toStringAsFixed(1)}%',
                    ),
                    _InfoChip('% Change', percentChange),
                    _InfoChip(
                      'Food',
                      item.entry.foodWeightGrams == null
                          ? '--'
                          : '${item.entry.foodWeightGrams!.toStringAsFixed(1)} g',
                    ),
                    _InfoChip('Condition', item.entry.conditionLabel ?? '--'),
                  ],
                ),
                if ((item.entry.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(item.entry.notes!),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DailyTrackerSheetScreen extends StatefulWidget {
  const _DailyTrackerSheetScreen({
    required this.controller,
    required this.mouse,
  });

  final FoodRestrictionController controller;
  final FoodRestrictionMouse mouse;

  @override
  State<_DailyTrackerSheetScreen> createState() => _DailyTrackerSheetScreenState();
}

class _DailyTrackerSheetScreenState extends State<_DailyTrackerSheetScreen> {
  final List<_EntryDraft> _drafts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _rebuildDrafts();
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final computed = _computedDrafts();
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.mouse.mouseName} Daily Tracker'),
        actions: [
          IconButton(
            tooltip: 'Add row',
            onPressed: _addRow,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Tracker Sheet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Edit daily rows directly on the phone. First saved weight stays the 100% baseline.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            _drafts.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DailyTrackerRowCard(
                draft: _drafts[index],
                computed: computed[index],
                onSave: () => _saveDraft(_drafts[index]),
                onDelete: () => _deleteDraft(_drafts[index]),
                saving: _loading,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _loading ? null : _addRow,
            icon: const Icon(Icons.add),
            label: const Text('Add Another Row'),
          ),
        ],
      ),
    );
  }

  void _rebuildDrafts() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    _drafts
      ..clear()
      ..addAll(
        widget.controller
            .entriesForMouse(widget.mouse.id)
            .map(_EntryDraft.fromEntry)
            .toList(),
      );
    if (_drafts.isEmpty) {
      _drafts.add(_EntryDraft.empty());
    }
  }

  void _addRow() {
    final sorted = [..._drafts]..sort((a, b) => a.sortDate.compareTo(b.sortDate));
    final last = sorted.isEmpty ? null : sorted.last;
    final nextDate = last?.parsedDate?.add(const Duration(days: 1)) ?? DateTime.now();
    setState(() {
      _drafts.add(
        _EntryDraft(
          dateController: TextEditingController(text: _formatDate(nextDate)),
          personController:
              TextEditingController(text: last?.personController.text.trim() ?? ''),
          weightController: TextEditingController(),
          foodController:
              TextEditingController(text: last?.foodController.text.trim() ?? ''),
          conditionController: TextEditingController(
            text: last?.conditionController.text.trim().isNotEmpty == true
                ? last!.conditionController.text.trim()
                : 'Good',
          ),
          notesController: TextEditingController(),
        ),
      );
    });
  }

  List<_DraftComputed> _computedDrafts() {
    final sorted = [..._drafts]..sort((a, b) => a.sortDate.compareTo(b.sortDate));
    double? baseline;
    double? previous;
    final map = <_EntryDraft, _DraftComputed>{};
    for (final draft in sorted) {
      final weight = draft.parsedWeight;
      if (weight != null && weight > 0 && baseline == null) {
        baseline = weight;
      }
      final percentOfOriginal =
          baseline == null || weight == null || weight <= 0 ? null : (weight / baseline) * 100;
      final percentChange = previous == null || weight == null || previous <= 0
          ? null
          : ((weight - previous) / previous) * 100;
      if (weight != null && weight > 0) {
        previous = weight;
      }
      map[draft] = _DraftComputed(
        percentOfOriginal: percentOfOriginal,
        percentChange: percentChange,
      );
    }
    return _drafts.map((draft) => map[draft] ?? const _DraftComputed()).toList();
  }

  Future<void> _saveDraft(_EntryDraft draft) async {
    final parsedDate = draft.parsedDate;
    final parsedWeight = draft.parsedWeight;
    if (parsedDate == null || parsedWeight == null || parsedWeight <= 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Each row needs a valid date and weight.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.controller.saveEntry(
        FoodRestrictionEntry(
          id: draft.entryId ?? 'fr-entry-${DateTime.now().microsecondsSinceEpoch}',
          experimentMouseId: widget.mouse.id,
          entryDate: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
          personPerforming: draft.personController.text.trim(),
          weightGrams: parsedWeight,
          foodWeightGrams: double.tryParse(draft.foodController.text.trim()),
          conditionLabel: _emptyToNull(draft.conditionController.text),
          notes: _emptyToNull(draft.notesController.text),
          createdAt: draft.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await widget.controller.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _rebuildDrafts();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily tracker row saved.')),
      );
    } on DuplicateFoodRestrictionEntryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _deleteDraft(_EntryDraft draft) async {
    if (draft.entryId == null) {
      setState(() {
        _drafts.remove(draft);
        draft.dispose();
        if (_drafts.isEmpty) {
          _drafts.add(_EntryDraft.empty());
        }
      });
      return;
    }
    setState(() => _loading = true);
    await widget.controller.deleteEntry(draft.entryId!);
    await widget.controller.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _rebuildDrafts();
    });
  }
}

class _DailyTrackerRowCard extends StatelessWidget {
  const _DailyTrackerRowCard({
    required this.draft,
    required this.computed,
    required this.onSave,
    required this.onDelete,
    required this.saving,
  });

  final _EntryDraft draft;
  final _DraftComputed computed;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final percentOriginal = computed.percentOfOriginal == null
        ? '--'
        : '${computed.percentOfOriginal!.toStringAsFixed(1)}%';
    final percentChange = computed.percentChange == null
        ? '0.00%'
        : '${computed.percentChange!.toStringAsFixed(2)}%';
    final risky = (computed.percentOfOriginal ?? 100) < 80;
    return Card(
      color: risky ? const Color(0xFFFFF1F2) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    draft.entryId == null ? 'New Row' : 'Saved Row',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.save_outlined),
                  onPressed: saving ? null : onSave,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: saving ? null : onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: draft.dateController,
              decoration: const InputDecoration(labelText: 'Date'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: draft.personController,
              decoration: const InputDecoration(labelText: 'Person Performing'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight (g)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: draft.foodController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Food (g)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: draft.conditionController,
              decoration: const InputDecoration(labelText: 'Condition'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: draft.notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip('% Original', percentOriginal),
                _InfoChip('% Change', percentChange),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryDraft {
  _EntryDraft({
    this.entryId,
    this.createdAt,
    required this.dateController,
    required this.personController,
    required this.weightController,
    required this.foodController,
    required this.conditionController,
    required this.notesController,
  });

  final String? entryId;
  final DateTime? createdAt;
  final TextEditingController dateController;
  final TextEditingController personController;
  final TextEditingController weightController;
  final TextEditingController foodController;
  final TextEditingController conditionController;
  final TextEditingController notesController;

  factory _EntryDraft.fromEntry(FoodRestrictionEntry entry) {
    return _EntryDraft(
      entryId: entry.id,
      createdAt: entry.createdAt,
      dateController: TextEditingController(text: _formatDate(entry.entryDate)),
      personController: TextEditingController(text: entry.personPerforming),
      weightController:
          TextEditingController(text: entry.weightGrams.toStringAsFixed(1)),
      foodController: TextEditingController(
        text: entry.foodWeightGrams?.toStringAsFixed(1) ?? '',
      ),
      conditionController:
          TextEditingController(text: entry.conditionLabel ?? 'Good'),
      notesController: TextEditingController(text: entry.notes ?? ''),
    );
  }

  factory _EntryDraft.empty() {
    return _EntryDraft(
      dateController: TextEditingController(text: _formatDate(DateTime.now())),
      personController: TextEditingController(),
      weightController: TextEditingController(),
      foodController: TextEditingController(),
      conditionController: TextEditingController(text: 'Good'),
      notesController: TextEditingController(),
    );
  }

  DateTime get sortDate => parsedDate ?? DateTime(2100);

  DateTime? get parsedDate => _parseDate(dateController.text);

  double? get parsedWeight => double.tryParse(weightController.text.trim());

  void dispose() {
    dateController.dispose();
    personController.dispose();
    weightController.dispose();
    foodController.dispose();
    conditionController.dispose();
    notesController.dispose();
  }
}

class _DraftComputed {
  const _DraftComputed({
    this.percentOfOriginal,
    this.percentChange,
  });

  final double? percentOfOriginal;
  final double? percentChange;
}

class _ExperimentCard extends StatelessWidget {
  const _ExperimentCard({
    required this.experiment,
    required this.miceCount,
    required this.latestAlertCount,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final FoodRestrictionExperiment experiment;
  final int miceCount;
  final int latestAlertCount;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      experiment.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(experiment.isActive ? 'Active' : 'Closed'),
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
              if ((experiment.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(experiment.description!),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _InfoChip('Mice', '$miceCount'),
                  const SizedBox(width: 8),
                  _InfoChip('Low Alerts', '$latestAlertCount'),
                  const SizedBox(width: 8),
                  _InfoChip('Started', _formatDate(experiment.startedAt)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopStat extends StatelessWidget {
  const _TopStat({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsSummaryRow extends StatelessWidget {
  const _AnalyticsSummaryRow({
    required this.latest,
    required this.entryCount,
  });

  final ComputedFoodRestrictionEntry? latest;
  final int entryCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TopStat(
            title: 'Entries',
            value: '$entryCount',
            color: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TopStat(
            title: '% Original',
            value: latest == null
                ? '--'
                : '${latest!.percentOfOriginal.toStringAsFixed(1)}%',
            color: latest != null && latest!.percentOfOriginal < 80
                ? const Color(0xFFDC2626)
                : const Color(0xFF0F766E),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TopStat(
            title: 'Food Today',
            value: latest?.entry.foodWeightGrams == null
                ? '--'
                : '${latest!.entry.foodWeightGrams!.toStringAsFixed(1)} g',
            color: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }
}

class _FoodRestrictionTrendChart extends StatelessWidget {
  const _FoodRestrictionTrendChart({
    required this.entries,
  });

  final List<ComputedFoodRestrictionEntry> entries;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendChartPainter(entries),
      child: Container(),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter(this.entries);

  final List<ComputedFoodRestrictionEntry> entries;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 38.0;
    const bottomPad = 28.0;
    const topPad = 14.0;
    final chartWidth = size.width - leftPad - 10;
    final chartHeight = size.height - topPad - bottomPad;
    final origin = Offset(leftPad, topPad + chartHeight);

    final axisPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(leftPad, topPad), origin, axisPaint);
    canvas.drawLine(origin, Offset(leftPad + chartWidth, origin.dy), axisPaint);

    const thresholds = [90.0, 85.0, 80.0, 75.0];
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final threshold in thresholds) {
      final y = topPad + chartHeight - ((threshold - 70) / 35) * chartHeight;
      final paint = Paint()
        ..color = threshold <= 80
            ? const Color(0xFFFCA5A5)
            : const Color(0xFFCBD5E1)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + chartWidth, y), paint);
      labelPainter.text = TextSpan(
        text: '${threshold.toInt()}%',
        style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(2, y - 6));
    }

    if (entries.length == 1) {
      final point = Offset(leftPad + chartWidth / 2, _percentY(entries.first.percentOfOriginal, topPad, chartHeight));
      final weightPaint = Paint()..color = const Color(0xFF0F766E);
      canvas.drawCircle(point, 4, weightPaint);
      return;
    }

    final percentPath = Path();
    final foodPath = Path();
    final maxFood = entries
        .map((entry) => entry.entry.foodWeightGrams ?? 0)
        .fold<double>(0, math.max);

    for (var i = 0; i < entries.length; i += 1) {
      final x = leftPad + (chartWidth * i / (entries.length - 1));
      final percentY =
          _percentY(entries[i].percentOfOriginal, topPad, chartHeight);
      if (i == 0) {
        percentPath.moveTo(x, percentY);
      } else {
        percentPath.lineTo(x, percentY);
      }

      final food = entries[i].entry.foodWeightGrams;
      if (food != null && maxFood > 0) {
        final foodY = topPad + chartHeight - ((food / maxFood) * chartHeight);
        if (foodPath == Path()) {
          foodPath.moveTo(x, foodY);
        }
      }
    }

    final percentPaint = Paint()
      ..color = const Color(0xFF0F766E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(percentPath, percentPaint);

    final foodPoints = <Offset>[];
    for (var i = 0; i < entries.length; i += 1) {
      final food = entries[i].entry.foodWeightGrams;
      if (food == null || maxFood <= 0) {
        continue;
      }
      final x = leftPad + (chartWidth * i / (entries.length - 1));
      final foodY = topPad + chartHeight - ((food / maxFood) * chartHeight);
      foodPoints.add(Offset(x, foodY));
    }
    if (foodPoints.length >= 2) {
      final path = Path()..moveTo(foodPoints.first.dx, foodPoints.first.dy);
      for (final point in foodPoints.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    for (var i = 0; i < entries.length; i += 1) {
      final x = leftPad + (chartWidth * i / (entries.length - 1));
      final y = _percentY(entries[i].percentOfOriginal, topPad, chartHeight);
      final pointPaint = Paint()
        ..color = entries[i].percentOfOriginal < 80
            ? const Color(0xFFDC2626)
            : const Color(0xFF0F766E);
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
  }

  double _percentY(double percent, double topPad, double chartHeight) {
    final clamped = percent.clamp(70, 105);
    return topPad + chartHeight - (((clamped - 70) / 35) * chartHeight);
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.entries != entries;
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _ExperimentEditorSheet extends StatefulWidget {
  const _ExperimentEditorSheet({
    required this.controller,
    this.existing,
  });

  final FoodRestrictionController controller;
  final FoodRestrictionExperiment? existing;

  @override
  State<_ExperimentEditorSheet> createState() => _ExperimentEditorSheetState();
}

class _ExperimentEditorSheetState extends State<_ExperimentEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _startController;
  late final TextEditingController _notesController;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.existing?.description ?? '');
    _startController = TextEditingController(
      text: _formatDate(widget.existing?.startedAt ?? DateTime.now()),
    );
    _notesController = TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _startController.dispose();
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
            children: [
              Text(
                _isEditing ? 'Edit Experiment' : 'Add Experiment',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Experiment Name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _startController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Started On'),
                onTap: () async {
                  final initial =
                      _parseDate(_startController.text) ?? DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    _startController.text = _formatDate(picked);
                  }
                },
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
                  onPressed: _saving ? null : _save,
                  child: Text(_saving
                      ? 'Saving...'
                      : _isEditing
                          ? 'Update Experiment'
                          : 'Save Experiment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final startedAt = _parseDate(_startController.text) ?? DateTime.now();
    final now = DateTime.now();
    setState(() => _saving = true);
    await widget.controller.saveExperiment(
      FoodRestrictionExperiment(
        id: widget.existing?.id ?? 'fr-exp-${now.microsecondsSinceEpoch}',
        name: _nameController.text.trim(),
        description: _emptyToNull(_descriptionController.text),
        startedAt: startedAt,
        endedAt: widget.existing?.endedAt,
        notes: _emptyToNull(_notesController.text),
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

class _ExperimentMouseEditorSheet extends StatefulWidget {
  const _ExperimentMouseEditorSheet({
    required this.controller,
    required this.experiment,
    this.existing,
  });

  final FoodRestrictionController controller;
  final FoodRestrictionExperiment experiment;
  final FoodRestrictionMouse? existing;

  @override
  State<_ExperimentMouseEditorSheet> createState() =>
      _ExperimentMouseEditorSheetState();
}

class _ExperimentMouseEditorSheetState extends State<_ExperimentMouseEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _serialController;
  late final TextEditingController _mouseTypeController;
  late final TextEditingController _groupController;
  late final TextEditingController _genderController;
  late final TextEditingController _baselineController;
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _serialController =
        TextEditingController(text: widget.existing?.serialNo ?? '');
    _mouseTypeController =
        TextEditingController(text: widget.existing?.mouseType ?? '');
    _groupController =
        TextEditingController(text: widget.existing?.groupName ?? '');
    _genderController =
        TextEditingController(text: widget.existing?.gender ?? 'MALE');
    _baselineController = TextEditingController(
      text: widget.existing?.baselineWeightGrams?.toStringAsFixed(1) ?? '',
    );
    _nameController =
        TextEditingController(text: widget.existing?.mouseName ?? '');
    _notesController =
        TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _serialController.dispose();
    _mouseTypeController.dispose();
    _groupController.dispose();
    _genderController.dispose();
    _baselineController.dispose();
    _nameController.dispose();
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
            children: [
              Text(
                _isEditing ? 'Edit Tracked Mouse' : 'Add Tracked Mouse',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _serialController,
                decoration: const InputDecoration(labelText: 'Serial No'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Mouse Name / Mouse ID'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mouseTypeController,
                decoration: const InputDecoration(labelText: 'Mouse Type'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _groupController,
                decoration: const InputDecoration(labelText: 'Group'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _genderController.text,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'MALE', child: Text('MALE')),
                  DropdownMenuItem(value: 'FEMALE', child: Text('FEMALE')),
                  DropdownMenuItem(value: 'UNKNOWN', child: Text('UNKNOWN')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _genderController.text = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _baselineController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Original / Baseline Weight (g)'),
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
                  onPressed: _saving ? null : _save,
                  child: Text(_saving
                      ? 'Saving...'
                      : _isEditing
                          ? 'Update Mouse'
                          : 'Save Mouse'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final now = DateTime.now();
    setState(() => _saving = true);
    await widget.controller.saveExperimentMouse(
      FoodRestrictionMouse(
        id: widget.existing?.id ?? 'fr-mouse-${now.microsecondsSinceEpoch}',
        experimentId: widget.experiment.id,
        serialNo: _serialController.text.trim(),
        mouseType: _mouseTypeController.text.trim(),
        groupName: _groupController.text.trim(),
        gender: _genderController.text.trim().toUpperCase(),
        baselineWeightGrams: double.tryParse(_baselineController.text.trim()),
        mouseName: _nameController.text.trim(),
        notes: _emptyToNull(_notesController.text),
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

class _FoodRestrictionEntryEditorSheet extends StatefulWidget {
  const _FoodRestrictionEntryEditorSheet({
    required this.controller,
    required this.mouse,
    this.existing,
    this.prefillFrom,
  });

  final FoodRestrictionController controller;
  final FoodRestrictionMouse mouse;
  final FoodRestrictionEntry? existing;
  final FoodRestrictionEntry? prefillFrom;

  @override
  State<_FoodRestrictionEntryEditorSheet> createState() =>
      _FoodRestrictionEntryEditorSheetState();
}

class _FoodRestrictionEntryEditorSheetState
    extends State<_FoodRestrictionEntryEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  late final TextEditingController _personController;
  late final TextEditingController _weightController;
  late final TextEditingController _foodController;
  late final TextEditingController _conditionController;
  late final TextEditingController _notesController;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: _formatDate(widget.existing?.entryDate ?? DateTime.now()),
    );
    _personController =
        TextEditingController(
          text: widget.existing?.personPerforming ??
              widget.prefillFrom?.personPerforming ??
              '',
        );
    _weightController = TextEditingController(
      text: widget.existing?.weightGrams.toStringAsFixed(1) ?? '',
    );
    _foodController = TextEditingController(
      text: widget.existing?.foodWeightGrams?.toStringAsFixed(1) ??
          widget.prefillFrom?.foodWeightGrams?.toStringAsFixed(1) ??
          '',
    );
    _conditionController =
        TextEditingController(
          text: widget.existing?.conditionLabel ??
              widget.prefillFrom?.conditionLabel ??
              'Good',
        );
    _notesController =
        TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _dateController.dispose();
    _personController.dispose();
    _weightController.dispose();
    _foodController.dispose();
    _conditionController.dispose();
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
            children: [
              Text(
                _isEditing ? 'Edit Daily Entry' : 'Add Daily Entry',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Date'),
                onTap: () async {
                  final initial =
                      _parseDate(_dateController.text) ?? DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    _dateController.text = _formatDate(picked);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _personController,
                decoration: const InputDecoration(labelText: 'Person Performing'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight (g)'),
                validator: (value) {
                  final number = double.tryParse((value ?? '').trim());
                  if (number == null || number <= 0) {
                    return 'Enter a valid weight';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _foodController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Food Weight (g)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _conditionController.text,
                decoration: const InputDecoration(labelText: 'Condition'),
                items: const [
                  DropdownMenuItem(value: 'Good', child: Text('Good')),
                  DropdownMenuItem(value: 'Monitor', child: Text('Monitor')),
                  DropdownMenuItem(value: 'Surgery', child: Text('Surgery')),
                  DropdownMenuItem(value: 'Tail injury', child: Text('Tail injury')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _conditionController.text = value;
                  }
                },
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
                  onPressed: _saving ? null : _save,
                  child: Text(_saving
                      ? 'Saving...'
                      : _isEditing
                          ? 'Update Entry'
                          : 'Save Entry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final entryDate = _parseDate(_dateController.text) ?? DateTime.now();
    final weight = double.tryParse(_weightController.text.trim());
    if (weight == null || weight <= 0) {
      return;
    }
    final now = DateTime.now();
    setState(() => _saving = true);
    try {
      await widget.controller.saveEntry(
        FoodRestrictionEntry(
          id: widget.existing?.id ?? 'fr-entry-${now.microsecondsSinceEpoch}',
          experimentMouseId: widget.mouse.id,
          entryDate: DateTime(entryDate.year, entryDate.month, entryDate.day),
          personPerforming: _personController.text.trim(),
          weightGrams: weight,
          foodWeightGrams: double.tryParse(_foodController.text.trim()),
          conditionLabel: _emptyToNull(_conditionController.text),
          notes: _emptyToNull(_notesController.text),
          createdAt: widget.existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    } on DuplicateFoodRestrictionEntryException catch (error) {
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
    final computed = widget.controller.computedEntriesForMouse(widget.mouse.id);
    final latest = computed.isEmpty ? null : computed.last;
    if (latest != null && latest.percentOfOriginal < 80) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Warning: ${widget.mouse.mouseName} is at ${latest.percentOfOriginal.toStringAsFixed(1)}% of baseline.',
          ),
        ),
      );
    }
    Navigator.of(context).pop();
  }
}

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  return null;
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _parseDate(String input) {
  final parts = input.split('/');
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
