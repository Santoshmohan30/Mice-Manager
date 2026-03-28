import 'package:flutter/foundation.dart';

import '../../application/services/breeding_service.dart';
import '../../domain/models/breeding.dart';

class BreedingController extends ChangeNotifier {
  BreedingController(this._service);

  final BreedingService _service;

  List<Breeding> _items = const [];
  bool _isLoading = false;

  List<Breeding> get items => _items;
  bool get isLoading => _isLoading;
  int get totalCount => _items.length;
  int get activeCount => _items.where((item) => item.endedAt == null).length;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _items = await _service.listAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> save(Breeding breeding) async {
    await _service.save(breeding);
    await load();
  }

  Future<void> delete(String breedingId) async {
    await _service.delete(breedingId);
    await load();
  }
}
