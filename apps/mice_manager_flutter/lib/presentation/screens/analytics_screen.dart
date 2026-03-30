import 'package:flutter/material.dart';

import '../../domain/models/housing_type.dart';
import '../../domain/models/mouse.dart';
import '../state/mice_controller.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    super.key,
    required this.controller,
  });

  final MiceController controller;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _strainFilter = 'All strains';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final mice = widget.controller.allMice
            .where((mouse) =>
                _strainFilter == 'All strains' || mouse.strain == _strainFilter)
            .toList();
        final strains = [
          'All strains',
          ...widget.controller.allMice.map((mouse) => mouse.strain).toSet().toList()
            ..sort(),
        ];
        final genotypeCounts = <String, int>{};
        for (final mouse in mice) {
          genotypeCounts[mouse.genotype] = (genotypeCounts[mouse.genotype] ?? 0) + 1;
        }
        final laf = mice.where((m) => m.housingType == HousingType.laf).length;
        final lab = mice.where((m) => m.housingType == HousingType.lab).length;
        final male = mice.where((m) => m.gender == 'MALE').length;
        final female = mice.where((m) => m.gender == 'FEMALE').length;
        final unknown = mice.where((m) => m.gender == 'UNKNOWN').length;

        return Scaffold(
          appBar: AppBar(title: const Text('Analytics')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _strainFilter,
                decoration: const InputDecoration(labelText: 'Filter by strain'),
                items: strains
                    .map(
                      (strain) => DropdownMenuItem(
                        value: strain,
                        child: Text(strain),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _strainFilter = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              _AnalyticsCard(
                title: 'Housing Distribution',
                child: _TwoBarChart(
                  leftLabel: 'LAF',
                  leftValue: laf,
                  leftColor: const Color(0xFF14B8A6),
                  rightLabel: 'LAB',
                  rightValue: lab,
                  rightColor: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(height: 16),
              _AnalyticsCard(
                title: 'Gender Distribution',
                child: _ThreeBarChart(
                  entries: [
                    _BarEntry('Male', male, const Color(0xFF2563EB)),
                    _BarEntry('Female', female, const Color(0xFFDB2777)),
                    _BarEntry('Unknown', unknown, const Color(0xFF6B7280)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _AnalyticsCard(
                title: 'Genotype Completion',
                child: _ThreeBarChart(
                  entries: [
                    _BarEntry(
                      'Not sure',
                      genotypeCounts['Not sure'] ?? 0,
                      const Color(0xFFF59E0B),
                    ),
                    _BarEntry(
                      'Positive',
                      genotypeCounts['Positive'] ?? 0,
                      const Color(0xFF0F766E),
                    ),
                    _BarEntry(
                      'Negative',
                      genotypeCounts['Negative'] ?? 0,
                      const Color(0xFF7C3AED),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _AnalyticsCard(
                title: 'Strain Totals',
                child: Column(
                  children: _strainRows(mice),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _strainRows(List<Mouse> mice) {
    final byStrain = <String, int>{};
    for (final mouse in mice) {
      byStrain[mouse.strain] = (byStrain[mouse.strain] ?? 0) + 1;
    }
    final entries = byStrain.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return const [Text('No mice available for analytics yet.')];
    }
    return entries
        .map(
          (entry) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.key),
            trailing: Text('${entry.value}'),
          ),
        )
        .toList();
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _TwoBarChart extends StatelessWidget {
  const _TwoBarChart({
    required this.leftLabel,
    required this.leftValue,
    required this.leftColor,
    required this.rightLabel,
    required this.rightValue,
    required this.rightColor,
  });

  final String leftLabel;
  final int leftValue;
  final Color leftColor;
  final String rightLabel;
  final int rightValue;
  final Color rightColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SingleBar(label: leftLabel, value: leftValue, color: leftColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              _SingleBar(label: rightLabel, value: rightValue, color: rightColor),
        ),
      ],
    );
  }
}

class _ThreeBarChart extends StatelessWidget {
  const _ThreeBarChart({
    required this.entries,
  });

  final List<_BarEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: entries
          .map(
            (entry) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _SingleBar(
                  label: entry.label,
                  value: entry.value,
                  color: entry.color,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SingleBar extends StatelessWidget {
  const _SingleBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final height = value == 0 ? 8.0 : (value * 18).clamp(18, 180).toDouble();
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _BarEntry {
  const _BarEntry(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}
