import '../../domain/models/breeding.dart';
import '../../domain/repositories/breeding_repository.dart';

class BreedingService {
  const BreedingService(this._repository);

  final BreedingRepository _repository;

  Future<List<Breeding>> listAll() => _repository.listAll();

  Future<void> save(Breeding breeding) => _repository.save(breeding);

  Future<void> delete(String breedingId) => _repository.delete(breedingId);
}
