import 'package:flutter/material.dart';

import '../../application/services/ocr_parser_service.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/models/calendar_task.dart';
import '../../domain/models/housing_type.dart';
import '../../domain/models/mouse.dart';
import '../../domain/models/role.dart';
import '../../infrastructure/ocr/android_mlkit_ocr_adapter.dart';
import '../state/auth_controller.dart';
import '../state/breeding_controller.dart';
import '../state/calendar_task_controller.dart';
import '../state/food_restriction_controller.dart';
import '../state/mice_controller.dart';
import '../state/ocr_history_controller.dart';
import '../state/procedure_controller.dart';
import '../state/sync_controller.dart';
import 'breeding_screen.dart';
import 'calendar_tasks_screen.dart';
import 'food_restriction_screen.dart';
import 'genotyping_screen.dart';
import 'login_screen.dart';
import 'mice_screen.dart';
import 'ocr_intake_screen.dart';
import 'procedures_screen.dart';
import 'sync_screen.dart';
import 'analytics_screen.dart';
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
    required this.foodRestrictionController,
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
  final FoodRestrictionController foodRestrictionController;
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
        foodRestrictionController: widget.foodRestrictionController,
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
      FoodRestrictionScreen(controller: widget.foodRestrictionController),
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
          NavigationDestination(
              icon: Icon(Icons.monitor_weight_outlined), label: 'Food'),
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
    required this.foodRestrictionController,
  });

  final MiceController controller;
  final BreedingController breedingController;
  final CalendarTaskController calendarTaskController;
  final ProcedureController procedureController;
  final OCRHistoryController ocrHistoryController;
  final SyncController syncController;
  final FoodRestrictionController foodRestrictionController;

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
        foodRestrictionController,
      ]),
      builder: (context, _) {
        final now = DateTime.now();
        final genotypePendingMice = controller.allMice
            .where((mouse) => mouse.genotype == 'Not sure')
            .toList()
          ..sort((a, b) => a.cageNumber.compareTo(b.cageNumber));
        final genotypePendingCount = genotypePendingMice.length;
        final genotypedDoneCount =
            controller.allMice.where((mouse) => mouse.genotype != 'Not sure').length;
        final openWeaningTasks = calendarTaskController.tasks
            .where((task) => !task.isDone && task.taskType == 'weaning')
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final nextWeaningTask =
            openWeaningTasks.isEmpty ? null : openWeaningTasks.first;
        final weaningThisMonth = openWeaningTasks
            .where((task) =>
                task.dueDate.year == now.year &&
                task.dueDate.month == now.month)
            .length;
        final openTaskCount =
            calendarTaskController.tasks.where((task) => !task.isDone).length;
        final activeFoodExperiments = foodRestrictionController.activeExperimentCount;
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _PriorityStat(
                            title: 'Pending Genotyping',
                            value: genotypePendingCount.toString(),
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PriorityStat(
                            title: 'Genotyped',
                            value: genotypedDoneCount.toString(),
                            color: const Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PriorityStat(
                            title: 'Next Weaning',
                            value: nextWeaningTask == null
                                ? '--'
                                : _formatShortDate(nextWeaningTask.dueDate),
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PriorityStat(
                            title: 'Open Tasks',
                            value: openTaskCount.toString(),
                            color: const Color(0xFF7C3AED),
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
                    title: 'Tracked food mice',
                    value: foodRestrictionController.trackedMouseCount.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DashboardStat(
                    title: 'Food Restriction',
                    value: activeFoodExperiments.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DashboardStat(
                    title: 'Sync bundles',
                    value: syncController.packages.length.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _GenotypingQueueCard(
              pendingMice: genotypePendingMice,
              onOpenGenotyping: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GenotypingScreen(controller: controller),
                  ),
                );
                if (!context.mounted) {
                  return;
                }
                await controller.load();
              },
              onMarkGenotype: (mouse, genotype) async {
                await controller.updateMouse(
                  mouse.copyWith(
                    genotype: genotype,
                    updatedAt: DateTime.now(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _WeaningTimelineCard(
              nextWeaningTask: nextWeaningTask,
              weaningThisMonth: weaningThisMonth,
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
              onMarkDone: nextWeaningTask == null
                  ? null
                  : () async {
                      await calendarTaskController.toggleDone(
                        nextWeaningTask,
                        true,
                      );
                    },
            ),
            const SizedBox(height: 16),
            _StrainAnalyticsCard(
              mice: controller.allMice,
              onOpenAnalytics: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AnalyticsScreen(controller: controller),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _WeaningTimelineCard extends StatelessWidget {
  const _WeaningTimelineCard({
    required this.nextWeaningTask,
    required this.weaningThisMonth,
    required this.onOpenCalendar,
    required this.onMarkDone,
  });

  final CalendarTask? nextWeaningTask;
  final int weaningThisMonth;
  final Future<void> Function() onOpenCalendar;
  final Future<void> Function()? onMarkDone;

  @override
  Widget build(BuildContext context) {
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
                    'Upcoming Weaning',
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
            if (nextWeaningTask == null)
              const Text('No open weaning tasks.')
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_note_outlined),
                title: Text(nextWeaningTask!.title),
                subtitle: Text(
                  '${_formatShortDate(nextWeaningTask!.dueDate)}${nextWeaningTask!.notes == null ? '' : '\n${nextWeaningTask!.notes}'}',
                ),
                isThreeLine: nextWeaningTask!.notes != null,
              ),
              const SizedBox(height: 6),
              Text(
                '$weaningThisMonth weaning task(s) this month',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonal(
                    onPressed: onMarkDone == null
                        ? null
                        : () async {
                            await onMarkDone!.call();
                          },
                    child: const Text('Mark Done'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onOpenCalendar,
                    child: const Text('Open Calendar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StrainAnalyticsCard extends StatelessWidget {
  const _StrainAnalyticsCard({
    required this.mice,
    required this.onOpenAnalytics,
  });

  final List<Mouse> mice;
  final Future<void> Function() onOpenAnalytics;

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
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: () async {
                  await onOpenAnalytics();
                },
                child: const Text('Open Analytics'),
              ),
            ),
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

class _PriorityStat extends StatelessWidget {
  const _PriorityStat({
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
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _GenotypingQueueCard extends StatelessWidget {
  const _GenotypingQueueCard({
    required this.pendingMice,
    required this.onOpenGenotyping,
    required this.onMarkGenotype,
  });

  final List<Mouse> pendingMice;
  final Future<void> Function() onOpenGenotyping;
  final Future<void> Function(Mouse mouse, String genotype) onMarkGenotype;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Genotyping Queue',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: () async {
                  await onOpenGenotyping();
                },
                child: const Text('Open Genotyping'),
              ),
            ),
            const SizedBox(height: 10),
            if (pendingMice.isEmpty)
              const Text('No cages are waiting for genotyping.')
            else
              ...pendingMice.take(6).map(
                    (mouse) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
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
                              'Cage ${mouse.cageNumber} • ${mouse.housingType == HousingType.laf ? 'LAF' : 'LAB'} • ${mouse.gender}',
                            ),
                            Text(
                              '${mouse.locationSummary} • DOB ${_formatShortDate(mouse.dateOfBirth)}',
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.tonal(
                                    onPressed: () async {
                                      await onMarkGenotype(mouse, 'Positive');
                                    },
                                    child: const Text('Mark Positive'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      await onMarkGenotype(mouse, 'Negative');
                                    },
                                    child: const Text('Mark Negative'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
