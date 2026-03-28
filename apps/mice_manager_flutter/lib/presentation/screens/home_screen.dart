import 'package:flutter/material.dart';

import '../../application/services/ocr_parser_service.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/models/breeding.dart';
import '../../domain/models/housing_type.dart';
import '../../domain/models/mouse.dart';
import '../../domain/models/role.dart';
import '../../infrastructure/ocr/android_mlkit_ocr_adapter.dart';
import '../state/auth_controller.dart';
import '../state/breeding_controller.dart';
import '../state/calendar_task_controller.dart';
import '../state/mice_controller.dart';
import '../state/ocr_history_controller.dart';
import '../state/procedure_controller.dart';
import '../state/sync_controller.dart';
import 'breeding_screen.dart';
import 'calendar_tasks_screen.dart';
import 'login_screen.dart';
import 'mice_screen.dart';
import 'ocr_intake_screen.dart';
import 'procedures_screen.dart';
import 'sync_screen.dart';
import 'users_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.authController,
    required this.controller,
    required this.breedingController,
    required this.calendarTaskController,
    required this.procedureController,
    required this.ocrHistoryController,
    required this.syncController,
    required this.ocrAdapter,
    required this.ocrParserService,
  });

  final AuthController authController;
  final MiceController controller;
  final BreedingController breedingController;
  final CalendarTaskController calendarTaskController;
  final ProcedureController procedureController;
  final OCRHistoryController ocrHistoryController;
  final SyncController syncController;
  final AndroidMlKitOCRAdapter ocrAdapter;
  final OCRParserService ocrParserService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _DashboardScreen(
        controller: widget.controller,
        breedingController: widget.breedingController,
        calendarTaskController: widget.calendarTaskController,
        procedureController: widget.procedureController,
        ocrHistoryController: widget.ocrHistoryController,
        syncController: widget.syncController,
      ),
      MiceScreen(controller: widget.controller),
      BreedingScreen(
        controller: widget.breedingController,
        mice: widget.controller.mice,
        onChanged: () => widget.calendarTaskController.syncFromBreedings(
          widget.breedingController.items,
          widget.controller.allMice,
        ),
      ),
      ProceduresScreen(
        controller: widget.procedureController,
        mice: widget.controller.mice,
      ),
      OCRIntakeScreen(
        controller: widget.controller,
        historyController: widget.ocrHistoryController,
        ocrAdapter: widget.ocrAdapter,
        parserService: widget.ocrParserService,
      ),
      SyncScreen(
        controller: widget.syncController,
        miceController: widget.controller,
        breedingController: widget.breedingController,
        procedureController: widget.procedureController,
        ocrHistoryController: widget.ocrHistoryController,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AppConstants.productName),
            Text(
              '${widget.authController.currentUser?.username ?? ''} • ${widget.authController.currentUser?.role.label ?? ''}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'users') {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        UsersScreen(controller: widget.authController),
                  ),
                );
                if (!context.mounted) {
                  return;
                }
                await widget.authController.refreshUsers();
              }
              if (value == 'signout') {
                await widget.authController.signOut();
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) =>
                        LoginScreen(controller: widget.authController),
                  ),
                  (_) => false,
                );
              }
            },
            itemBuilder: (context) => [
              if (widget.authController.currentUser != null &&
                  (widget.authController.currentUser!.role == Role.owner ||
                      widget.authController.currentUser!.role == Role.admin))
                const PopupMenuItem(
                  value: 'users',
                  child: Text('Users'),
                ),
              const PopupMenuItem(
                value: 'signout',
                child: Text('Sign Out'),
              ),
            ],
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.pest_control_rodent), label: 'Mice'),
          NavigationDestination(
              icon: Icon(Icons.family_restroom_outlined), label: 'Breeding'),
          NavigationDestination(
              icon: Icon(Icons.science_outlined), label: 'Procedures'),
          NavigationDestination(
              icon: Icon(Icons.document_scanner_outlined), label: 'OCR'),
          NavigationDestination(icon: Icon(Icons.sync_outlined), label: 'Sync'),
        ],
      ),
    );
  }
}

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen({
    required this.controller,
    required this.breedingController,
    required this.calendarTaskController,
    required this.procedureController,
    required this.ocrHistoryController,
    required this.syncController,
  });

  final MiceController controller;
  final BreedingController breedingController;
  final CalendarTaskController calendarTaskController;
  final ProcedureController procedureController;
  final OCRHistoryController ocrHistoryController;
  final SyncController syncController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller,
        breedingController,
        calendarTaskController,
        procedureController,
        ocrHistoryController,
        syncController,
      ]),
      builder: (context, _) {
        final upcomingTaskCount = calendarTaskController.tasks
            .where((task) =>
                !task.isDone &&
                task.dueDate
                    .isBefore(DateTime.now().add(const Duration(days: 7))))
            .length;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${calendarTaskController.openCount} open task(s), $upcomingTaskCount due within 7 days, ${controller.totalCount} total mice, and ${breedingController.activeCount} active breeding pair(s).',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Review dates, finish weaning tasks, and keep the colony records current for the team.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _DashboardStat(
                        title: 'Total mice',
                        value: controller.totalCount.toString())),
                const SizedBox(width: 12),
                Expanded(
                    child: _DashboardStat(
                        title: 'LAF', value: controller.lafCount.toString())),
                const SizedBox(width: 12),
                Expanded(
                    child: _DashboardStat(
                        title: 'LAB', value: controller.labCount.toString())),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DashboardStat(
                    title: 'Breeding pairs',
                    value: breedingController.totalCount.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DashboardStat(
                    title: 'Procedures',
                    value: procedureController.totalCount.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DashboardStat(
                    title: 'OCR scans',
                    value: ocrHistoryController.items.length.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DashboardStat(
                    title: 'Open tasks',
                    value: calendarTaskController.openCount.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _DashboardStat(
                title: 'Sync bundles',
                value: syncController.packages.length.toString(),
              ),
            ),
            const SizedBox(height: 16),
            _WeaningTimelineCard(
              breedings: breedingController.items,
              mice: controller.allMice,
              onOpenCalendar: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CalendarTasksScreen(controller: calendarTaskController),
                  ),
                );
                if (!context.mounted) {
                  return;
                }
                await calendarTaskController.load();
              },
            ),
            const SizedBox(height: 16),
            _StrainAnalyticsCard(mice: controller.allMice),
            const SizedBox(height: 16),
            const _ActionHint(
              title: 'What works now',
              body:
                  'Open Mice, Breeding, and Procedures to manage local offline records on the phone.',
            ),
          ],
        );
      },
    );
  }
}

class _WeaningTimelineCard extends StatelessWidget {
  const _WeaningTimelineCard({
    required this.breedings,
    required this.mice,
    required this.onOpenCalendar,
  });

  final List<Breeding> breedings;
  final List<Mouse> mice;
  final Future<void> Function() onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = breedings
        .where((item) => item.endedAt == null)
        .map<_ProjectedBreeding>((item) {
      final litterDate = item.startedAt
          .add(const Duration(days: AppConstants.mouseGestationDays));
      final weaningDate = litterDate
          .add(const Duration(days: AppConstants.mouseWeaningDaysAfterBirth));
      return _ProjectedBreeding(
        label: _pairLabel(item.maleMouseId, item.femaleMouseId),
        litterDate: litterDate,
        weaningDate: weaningDate,
      );
    }).toList()
      ..sort((a, b) => a.weaningDate.compareTo(b.weaningDate));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Weaning and Dates',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: onOpenCalendar,
                  child: const Text('Open Calendar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Active breeding pairs show projected litter and weaning dates. Open Calendar to mark tasks done or add day tasks.',
            ),
            const SizedBox(height: 12),
            if (active.isEmpty)
              const Text('No active breeding pairs yet.')
            else
              ...active.take(5).map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_note_outlined),
                      title: Text(item.label),
                      subtitle: Text(
                        'Litter: ${_formatShortDate(item.litterDate)} • Weaning: ${_formatShortDate(item.weaningDate)}',
                      ),
                      trailing: Text(
                        _daysLabel(item.weaningDate.difference(now).inDays),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _pairLabel(String maleMouseId, String femaleMouseId) {
    String findMouse(String id) {
      for (final mouse in mice) {
        if (mouse.id == id) {
          return '${mouse.strain} (${mouse.cageNumber})';
        }
      }
      return id;
    }

    return '${findMouse(maleMouseId)} x ${findMouse(femaleMouseId)}';
  }

  String _daysLabel(int days) {
    if (days == 0) {
      return 'Today';
    }
    if (days < 0) {
      return '${days.abs()}d overdue';
    }
    return 'In ${days}d';
  }
}

class _ProjectedBreeding {
  const _ProjectedBreeding({
    required this.label,
    required this.litterDate,
    required this.weaningDate,
  });

  final String label;
  final DateTime litterDate;
  final DateTime weaningDate;
}

class _StrainAnalyticsCard extends StatelessWidget {
  const _StrainAnalyticsCard({
    required this.mice,
  });

  final List<Mouse> mice;

  @override
  Widget build(BuildContext context) {
    final byStrain = <String, Map<String, int>>{};
    for (final mouse in mice) {
      final strain = mouse.strain;
      final bucket = byStrain.putIfAbsent(
        strain,
        () => <String, int>{'LAF': 0, 'LAB': 0},
      );
      final key = mouse.housingType == HousingType.laf ? 'LAF' : 'LAB';
      bucket[key] = (bucket[key] ?? 0) + 1;
    }
    final entries = byStrain.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Strain Analytics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Plots for each strain split by LAF and LAB.'),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Text('No mice available for analytics yet.')
            else
              ...entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _StrainBarPlot(
                    strain: entry.key,
                    laf: entry.value['LAF'] ?? 0,
                    lab: entry.value['LAB'] ?? 0,
                  ),
                ),
              ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 4),
              const Row(
                children: [
                  _LegendDot(color: Color(0xFF14B8A6), label: 'LAF'),
                  SizedBox(width: 16),
                  _LegendDot(color: Color(0xFFF59E0B), label: 'LAB'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatShortDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month/$day/${value.year}';
}

class _DashboardStat extends StatelessWidget {
  const _DashboardStat({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _StrainBarPlot extends StatelessWidget {
  const _StrainBarPlot({
    required this.strain,
    required this.laf,
    required this.lab,
  });

  final String strain;
  final int laf;
  final int lab;

  @override
  Widget build(BuildContext context) {
    final total = laf + lab;
    final lafFlex = laf == 0 ? 1 : laf;
    final labFlex = lab == 0 ? 1 : lab;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strain,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '$total total',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 16,
            child: Row(
              children: [
                Expanded(
                  flex: lafFlex,
                  child: Container(color: const Color(0xFF14B8A6)),
                ),
                Expanded(
                  flex: labFlex,
                  child: Container(color: const Color(0xFFF59E0B)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('LAF $laf • LAB $lab'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _ActionHint extends StatelessWidget {
  const _ActionHint({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(body),
      ),
    );
  }
}
