import '../models/food_restriction_entry.dart';
import '../models/food_restriction_experiment.dart';
import '../models/food_restriction_mouse.dart';

abstract class FoodRestrictionRepository {
  Future<List<FoodRestrictionExperiment>> listExperiments();
  Future<void> saveExperiment(FoodRestrictionExperiment experiment);
  Future<void> deleteExperiment(String experimentId);

  Future<List<FoodRestrictionMouse>> listExperimentMice();
  Future<void> saveExperimentMouse(FoodRestrictionMouse mouse);
  Future<void> deleteExperimentMouse(String mouseId);

  Future<List<FoodRestrictionEntry>> listEntries();
  Future<void> saveEntry(FoodRestrictionEntry entry);
  Future<void> deleteEntry(String entryId);
}
