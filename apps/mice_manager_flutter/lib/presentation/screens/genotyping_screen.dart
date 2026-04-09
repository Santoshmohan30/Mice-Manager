import 'package:flutter/material.dart';

import '../../domain/models/mouse.dart';
import '../state/mice_controller.dart';

class GenotypingScreen extends StatefulWidget {
  const GenotypingScreen({
    super.key,
    required this.controller,
  });

  final MiceController controller;

  @override
  State<GenotypingScreen> createState() => _GenotypingScreenState();
}

class _GenotypingScreenState extends State<GenotypingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final pending = widget.controller.allMice
            .where((mouse) => mouse.genotype == 'Not sure')
            .where((mouse) {
              if (_search.isEmpty) {
                return true;
              }
              final query = _search.toLowerCase();
              return mouse.cageNumber.toLowerCase().contains(query) ||
                  mouse.strain.toLowerCase().contains(query) ||
                  (mouse.rackLocation ?? '').toLowerCase().contains(query);
            })
            .toList()
          ..sort((a, b) => a.cageNumber.compareTo(b.cageNumber));

        final completed = widget.controller.allMice
            .where((mouse) => mouse.genotype != 'Not sure')
            .toList()
          ..sort((a, b) => b.updatedAt?.compareTo(a.updatedAt ?? DateTime(0)) ?? 0);

        return Scaffold(
          appBar: AppBar(title: const Text('Genotyping')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _GenotypingStat(
                      title: 'Pending',
                      value: pending.length.toString(),
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GenotypingStat(
                      title: 'Completed',
                      value: completed.length.toString(),
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search by cage, strain, or rack',
                ),
                onChanged: (value) {
                  setState(() => _search = value.trim());
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Genotyping',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (pending.isEmpty)
                        const Text('No cages are waiting for genotyping.')
                      else
                        ...pending.map(
                          (mouse) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _GenotypeMouseTile(
                              mouse: mouse,
                              onPositive: () => _updateMouse(mouse, 'Positive'),
                              onNegative: () => _updateMouse(mouse, 'Negative'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recently Genotyped',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (completed.isEmpty)
                        const Text('No mice have been marked yet.')
                      else
                        ...completed.take(10).map(
                          (mouse) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.check_circle_outline),
                            title: Text('${mouse.strain} • ${mouse.cageNumber}'),
                            subtitle: Text(
                              '${mouse.genotype} • ${mouse.locationSummary}',
                            ),
                          ),
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

  Future<void> _updateMouse(Mouse mouse, String genotype) async {
    await widget.controller.updateMouse(
      mouse.copyWith(
        genotype: genotype,
        updatedAt: DateTime.now(),
      ),
    );
  }
}

class _GenotypeMouseTile extends StatelessWidget {
  const _GenotypeMouseTile({
    required this.mouse,
    required this.onPositive,
    required this.onNegative,
  });

  final Mouse mouse;
  final Future<void> Function() onPositive;
  final Future<void> Function() onNegative;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.34),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mouse.strain,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Cage ${mouse.cageNumber} • ${mouse.housingType.name.toUpperCase()} • ${mouse.gender}',
          ),
          Text('${mouse.locationSummary} • DOB ${_formatDate(mouse.dateOfBirth)}'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () async {
                    await onPositive();
                  },
                  child: const Text('Mark Positive'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await onNegative();
                  },
                  child: const Text('Mark Negative'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenotypingStat extends StatelessWidget {
  const _GenotypingStat({
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(title),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  return '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year}';
}
