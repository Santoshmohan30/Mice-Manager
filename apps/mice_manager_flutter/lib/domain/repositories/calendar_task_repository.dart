import '../models/calendar_task.dart';

abstract class CalendarTaskRepository {
  Future<List<CalendarTask>> listAll();
  Future<void> save(CalendarTask task);
  Future<void> delete(String taskId);
}
