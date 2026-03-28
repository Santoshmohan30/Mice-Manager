import 'package:flutter/foundation.dart';

import '../../application/services/calendar_task_service.dart';
import '../../domain/models/breeding.dart';
import '../../domain/models/calendar_task.dart';
import '../../domain/models/mouse.dart';

class CalendarTaskController extends ChangeNotifier {
  CalendarTaskController(this._service);

  final CalendarTaskService _service;

  List<CalendarTask> _tasks = const [];
  bool _isLoading = false;

  List<CalendarTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  int get openCount => _tasks.where((task) => !task.isDone).length;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _tasks = await _service.listAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTask({
    required String title,
    required DateTime dueDate,
    String? notes,
  }) async {
    final now = DateTime.now();
    await _service.save(
      CalendarTask(
        id: 'task-${now.microsecondsSinceEpoch}',
        title: title.trim(),
        taskType: 'general',
        dueDate: dueDate,
        isDone: false,
        notes: notes?.trim().isEmpty ?? true ? null : notes?.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await load();
  }

  Future<void> toggleDone(CalendarTask task, bool isDone) async {
    await _service.toggleDone(task, isDone);
    await load();
  }

  Future<void> deleteTask(String taskId) async {
    await _service.delete(taskId);
    await load();
  }

  Future<void> syncFromBreedings(
    List<Breeding> breedings,
    List<Mouse> mice,
  ) async {
    await _service.syncBreedingTasks(breedings, mice);
    await load();
  }
}
