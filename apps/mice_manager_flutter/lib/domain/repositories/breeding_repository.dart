import '../models/breeding.dart';

abstract class BreedingRepository {
  Future<List<Breeding>> listAll();
  Future<void> save(Breeding breeding);
  Future<void> delete(String breedingId);
}
