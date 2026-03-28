import 'package:flutter/material.dart';

import '../../domain/models/calendar_task.dart';
import '../state/calendar_task_controller.dart';

class CalendarTasksScreen extends StatelessWidget {
  const CalendarTasksScreen({
    super.key,
    required this.controller,
  });

  final CalendarTaskController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final grouped = <String, List<CalendarTask>>{};
        for (final task in controller.tasks) {
          final key = _formatDate(task.dueDate);
          grouped.putIfAbsent(key, () => <CalendarTask>[]).add(task);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Calendar Tasks'),
          ),
          body: controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weaning and daily lab tasks',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Mark tasks done as you finish them. Weaning and litter check tasks are generated from active breeding pairs.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (grouped.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No tasks yet. Add one below.'),
                        ),
                      )
                    else
                      ...grouped.entries.map(
                        (entry) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                ...entry.value.map(
                                  (task) => CheckboxListTile(
                                    dense: true,
                                    value: task.isDone,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: Text(task.title),
                                    subtitle: Text(
                                      [
                                        task.taskType == 'general'
                                            ? 'Day task'
                                            : task.taskType == 'weaning'
                                                ? 'Weaning task'
                                                : 'Breeding task',
                                        if (task.notes != null &&
                                            task.notes!.trim().isNotEmpty)
                                          task.notes!,
                                      ].join('\n'),
                                    ),
                                    secondary: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () =>
                                          controller.deleteTask(task.id),
                                    ),
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      controller.toggleDone(task, value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _AddTaskSheet(controller: controller),
              );
            },
            icon: const Icon(Icons.add_task),
            label: const Text('Add Day Task'),
          ),
        );
      },
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet({
    required this.controller,
  });

  final CalendarTaskController controller;

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateController.text =
        '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Day Task',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Task title'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateController,
                decoration:
                    const InputDecoration(labelText: 'Due date (MM/DD/YYYY)'),
                validator: (value) =>
                    _parseDate(value) == null ? 'Enter a valid date' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }
                    final dueDate = _parseDate(_dateController.text);
                    if (dueDate == null) {
                      return;
                    }
                    await widget.controller.addTask(
                      title: _titleController.text,
                      dueDate: dueDate,
                      notes: _notesController.text,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save Task'),
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
  try {
    return DateTime(year, month, day);
  } catch (_) {
    return null;
  }
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month/$day/${value.year}';
}
