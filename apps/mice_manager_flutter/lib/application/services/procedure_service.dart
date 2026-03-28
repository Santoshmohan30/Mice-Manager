import '../../domain/models/procedure.dart';
import '../../domain/repositories/procedure_repository.dart';

class ProcedureService {
  const ProcedureService(this._repository);

  final ProcedureRepository _repository;

  Future<List<Procedure>> listAll() => _repository.listAll();

  Future<void> save(Procedure procedure) => _repository.save(procedure);

  Future<void> delete(String procedureId) => _repository.delete(procedureId);
}
