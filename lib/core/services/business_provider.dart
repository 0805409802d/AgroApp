// business_provider.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/business_model.dart';

class BusinessProvider extends ChangeNotifier {
  BusinessModel? _business;
  bool _loading = true;
  String? _error;

  BusinessModel? get business => _business;
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
          .maybeSingle(); // maybeSingle() retorna null en vez de lanzar excepción

      if (data != null) {
        _business = BusinessModel.fromMap(data);
        _error = null;
      } else {
        _business = null;
        _error = 'no_business'; // negocio no creado aún
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