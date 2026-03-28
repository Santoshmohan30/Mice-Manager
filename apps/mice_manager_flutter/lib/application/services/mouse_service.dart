import '../../domain/models/housing_type.dart';
import '../../domain/models/mouse.dart';
import '../../domain/repositories/mouse_repository.dart';

class MouseService {
  const MouseService(this._repository);

  final MouseRepository _repository;

  Future<List<Mouse>> listAll() => _repository.listAll();

  Future<List<Mouse>> listLaf() =>
      _repository.listByHousingType(HousingType.laf);

  Future<List<Mouse>> listLab() =>
      _repository.listByHousingType(HousingType.lab);

  Future<void> save(Mouse mouse) => _repository.save(mouse);

  Future<void> delete(String mouseId) => _repository.delete(mouseId);

  Future<bool> hasDuplicate(Mouse candidate) async {
    final mice = await _repository.listAll();
    return mice.any(
      (mouse) =>
          mouse.id != candidate.id &&
          mouse.cageNumber.trim().toUpperCase() ==
              candidate.cageNumber.trim().toUpperCase() &&
          mouse.strain.trim().toUpperCase() ==
              candidate.strain.trim().toUpperCase() &&
          mouse.gender.trim().toUpperCase() ==
              candidate.gender.trim().toUpperCase() &&
          mouse.genotype.trim().toUpperCase() ==
              candidate.genotype.trim().toUpperCase() &&
          mouse.dateOfBirth.year == candidate.dateOfBirth.year &&
          mouse.dateOfBirth.month == candidate.dateOfBirth.month &&
          mouse.dateOfBirth.day == candidate.dateOfBirth.day,
    );
  }
}
