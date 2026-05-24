import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/advance_model.dart';

class AdvanceProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<AdvanceModel> _pendingAdvances = [];
  bool _loading = false;

  List<AdvanceModel> get pendingAdvances => _pendingAdvances;
  bool get loading => _loading;

  // Cargar adelantos pendientes para un agricultor
  Future<void> loadPendingAdvances(String farmerId) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _supabase
          .from('advances')
          .select()
          .eq('farmer_id', farmerId)
          .eq('status', 'active')
          .gt('remaining', 0)
          .order('created_at');

      _pendingAdvances = data.map((e) => AdvanceModel.fromMap(e)).toList();
    } catch (e) {
      _pendingAdvances = [];
    }
    _loading = false;
    notifyListeners();
  }

  // Registrar un nuevo adelanto (préstamo)
  Future<void> createAdvance({
    required String businessId,
    required String farmerId,
    required double amount,
    String? notes,
  }) async {
    await _supabase.from('advances').insert({
      'business_id': businessId,
      'farmer_id': farmerId,
      'amount': amount,
      'remaining': amount,
      'status': 'active',
      'notes': notes,
    });
    // Recargar si estamos viendo los pendientes de este agricultor
    notifyListeners();
  }

  // Podrías añadir también cancelar adelanto, pero con cuidado.
}