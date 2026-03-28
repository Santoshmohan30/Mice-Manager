import 'package:flutter/foundation.dart';

import '../../application/services/procedure_service.dart';
import '../../domain/models/procedure.dart';

class ProcedureController extends ChangeNotifier {
  ProcedureController(this._service);

  final ProcedureService _service;

  List<Procedure> _items = const [];
  bool _isLoading = false;

  List<Procedure> get items => _items;
  bool get isLoading => _isLoading;
  int get totalCount => _items.length;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _items = await _service.listAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> save(Procedure procedure) async {
    await _service.save(procedure);
    await load();
  }

  Future<void> delete(String procedureId) async {
    await _service.delete(procedureId);
    await load();
  }
}
