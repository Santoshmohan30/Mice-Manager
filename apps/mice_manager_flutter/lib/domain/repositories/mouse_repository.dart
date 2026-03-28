import '../models/mouse.dart';
import '../models/housing_type.dart';

abstract class MouseRepository {
  Future<List<Mouse>> listAll();
  Future<List<Mouse>> listByHousingType(HousingType housingType);
  Future<void> save(Mouse mouse);
  Future<void> delete(String mouseId);
}
