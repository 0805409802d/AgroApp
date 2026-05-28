// business_provider.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/business_model.dart';
import '../../features/alarms/services/web_alarm_service.dart';

class BusinessProvider extends ChangeNotifier {
  BusinessModel? _business;
  String _role = 'operator';
  bool _loading = true;
  String? _error;

  BusinessModel? get business => _business;
  String get role => _role;
  bool get isAdmin => _role == 'admin';
  bool get loading => _loading;
  String? get error => _error;

  final _supabase = Supabase.instance.client;

  Future<void> loadBusiness() async {
    // Evita llamar a notifyListeners de forma síncrona mientras el widget se está construyendo
    await Future.microtask(() {});

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _supabase
          .from('businesses')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null) {
        _business = BusinessModel.fromMap(data);
        _role = 'admin';
        _error = null;
        WebAlarmService().initialize(_business!.id);
      } else {
        // Verificar si es un empleado activo
        final empData = await _supabase
            .from('employees')
            .select('role, business_id')
            .eq('user_id', userId)
            .eq('is_active', true)
            .maybeSingle();

        if (empData != null) {
          // Segundo query: leer el negocio directamente con business_id
          final bizData = await _supabase
              .from('businesses')
              .select()
              .eq('id', empData['business_id'])
              .maybeSingle();

          if (bizData != null) {
            _business = BusinessModel.fromMap(bizData);
            _role = empData['role'] as String? ?? 'operator';
            _error = null;
          } else {
            _business = null;
            _role = 'operator';
            _error = 'no_business';
          }
        } else {
          _business = null;
          _role = 'operator';
          _error = 'no_business';
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updatePrice(double newPrice) async {
    if (_business == null) return;

    await _supabase
        .from('businesses')
        .update({'current_price': newPrice}).eq('id', _business!.id);

    // Actualizamos localmente sin recargar toda la pantalla
    _business = BusinessModel(
      id: _business!.id,
      userId: _business!.userId,
      businessName: _business!.businessName,
      ownerName: _business!.ownerName,
      whatsappNumber: _business!.whatsappNumber,
      productType: _business!.productType,
      weightUnit: _business!.weightUnit,
      discountType: _business!.discountType,
      currentPrice: newPrice,
      isActive: _business!.isActive,
      subscriptionExpiresAt: _business!.subscriptionExpiresAt,
    );
    notifyListeners();
  }
}