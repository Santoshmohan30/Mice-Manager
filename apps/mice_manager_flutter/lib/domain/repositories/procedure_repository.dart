import '../models/procedure.dart';

abstract class ProcedureRepository {
  Future<List<Procedure>> listAll();
  Future<void> save(Procedure procedure);
  Future<void> delete(String procedureId);
}
