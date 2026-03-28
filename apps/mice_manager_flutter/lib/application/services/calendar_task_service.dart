import '../../core/constants/app_constants.dart';
import '../../domain/models/breeding.dart';
import '../../domain/models/calendar_task.dart';
import '../../domain/models/mouse.dart';
import '../../domain/repositories/calendar_task_repository.dart';

class CalendarTaskService {
  const CalendarTaskService(this._repository);

  final CalendarTaskRepository _repository;

  Future<List<CalendarTask>> listAll() => _repository.listAll();

  Future<void> save(CalendarTask task) => _repository.save(task);

  Future<void> delete(String taskId) => _repository.delete(taskId);

  Future<void> toggleDone(CalendarTask task, bool isDone) {
    return _repository.save(
      task.copyWith(
        isDone: isDone,
        completedAt: isDone ? DateTime.now() : null,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> syncBreedingTasks(
    List<Breeding> breedings,
    List<Mouse> mice,
  ) async {
    final existing = await _repository.listAll();
    for (final breeding in breedings.where((item) => item.endedAt == null)) {
      final pairDetails = _pairDetails(
        breeding.maleMouseId,
        breeding.femaleMouseId,
        mice,
      );
      await _ensureTask(
        existing: existing,
        sourceId: breeding.id,
        taskType: 'litter_check',
        title: 'Litter check: ${pairDetails.title}',
        dueDate: breeding.startedAt.add(
          const Duration(days: AppConstants.mouseGestationDays),
        ),
        notes: pairDetails.notes,
      );
      await _ensureTask(
        existing: existing,
        sourceId: breeding.id,
        taskType: 'weaning',
        title: 'Weaning: ${pairDetails.title}',
        dueDate: breeding.startedAt.add(
          const Duration(
            days: AppConstants.mouseGestationDays +
                AppConstants.mouseWeaningDaysAfterBirth,
          ),
        ),
        notes: pairDetails.notes,
      );
    }
  }

  Future<void> _ensureTask({
    required List<CalendarTask> existing,
    required String sourceId,
    required String taskType,
    required String title,
    required DateTime dueDate,
    String? notes,
  }) async {
    CalendarTask? match;
    for (final task in existing) {
      if (task.sourceType == 'breeding' &&
          task.sourceId == sourceId &&
          task.taskType == taskType) {
        match = task;
        break;
      }
    }
    if (match != null) {
      await _repository.save(
        match.copyWith(
          title: title,
          dueDate: dueDate,
          notes: notes,
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }
    final now = DateTime.now();
    await _repository.save(
      CalendarTask(
        id: 'task-$sourceId-$taskType',
        title: title,
        taskType: taskType,
        dueDate: dueDate,
        isDone: false,
        sourceType: 'breeding',
        sourceId: sourceId,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  _BreedingPairDetails _pairDetails(
    String maleMouseId,
    String femaleMouseId,
    List<Mouse> mice,
  ) {
    Mouse? findMouse(String id) {
      for (final mouse in mice) {
        if (mouse.id == id) {
          return mouse;
        }
      }
      return null;
    }

    final male = findMouse(maleMouseId);
    final female = findMouse(femaleMouseId);
    final maleLabel =
        male == null ? maleMouseId : 'Male ${male.strain} (${male.cageNumber})';
    final femaleLabel = female == null
        ? femaleMouseId
        : 'Female ${female.strain} (${female.cageNumber})';
    return _BreedingPairDetails(
      title:
          '${female?.strain ?? femaleMouseId} x ${male?.strain ?? maleMouseId}',
      notes: '$femaleLabel • $maleLabel',
    );
  }
}

class _BreedingPairDetails {
  const _BreedingPairDetails({
    required this.title,
    required this.notes,
  });

  final String title;
  final String notes;
}
