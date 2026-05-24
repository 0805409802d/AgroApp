import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/cash_session_model.dart';
import '../../shared/models/cash_movement_model.dart';

class CashProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  CashSessionModel? _currentSession;
  List<CashMovementModel> _movements = [];
  bool _loading = false;

  CashSessionModel? get currentSession => _currentSession;
  List<CashMovementModel> get movements => _movements;
  bool get loading => _loading;
  bool get hasOpenSession => _currentSession != null && _currentSession!.status == 'open';

  // Cargar la sesión de caja abierta hoy (o la última)
  Future<void> loadTodaySession(String businessId) async {
    _loading = true;
    notifyListeners();

    try {
      // Calculamos el rango del día en UTC para filtrar correctamente
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);
      final endOfDay   = startOfDay.add(const Duration(days: 1));

      final data = await _supabase
          .from('cash_sessions')
          .select()
          .eq('business_id', businessId)
          .eq('status', 'open')
          .gte('opened_at', startOfDay.toIso8601String())
          .lt('opened_at', endOfDay.toIso8601String())
          .maybeSingle();

      if (data != null) {
        _currentSession = CashSessionModel.fromMap(data);
        // Cargar movimientos asociados
        await _loadMovements(_currentSession!.id);
      } else {
        _currentSession = null;
        _movements = [];
      }
    } catch (e) {
      _currentSession = null;
      _movements = [];
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> _loadMovements(String sessionId) async {
    final data = await _supabase
        .from('cash_movements')
        .select()
        .eq('cash_session_id', sessionId)
        .order('created_at');
    _movements = (data as List).map((e) => CashMovementModel.fromMap(e)).toList();
  }

  // Abrir nueva caja
  Future<void> openCash({
    required String businessId,
    required double openingBalance,
    String? notes,
  }) async {
    await _supabase.from('cash_sessions').insert({
      'business_id': businessId,
      'opening_balance': openingBalance,
      'notes': notes,
      'status': 'open',
    });
    await loadTodaySession(businessId);
  }

  // Cerrar caja
  Future<void> closeCash({
    required String sessionId,
    required double closingBalance,
    String? notes,
  }) async {
    await _supabase
        .from('cash_sessions')
        .update({
          'closing_balance': closingBalance,
          'status': 'closed',
          'closed_at': DateTime.now().toUtc().toIso8601String(),
          'notes': notes ?? _currentSession?.notes,
        })
        .eq('id', sessionId);

    _currentSession = null;
    _movements = [];
    notifyListeners();
  }
}