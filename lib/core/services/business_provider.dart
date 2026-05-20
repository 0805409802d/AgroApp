// business_provider.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/business_model.dart';

class BusinessProvider extends ChangeNotifier {
  BusinessModel? _business;
  bool _loading = true;

  BusinessModel? get business => _business;
  bool get loading => _loading;

  final _supabase = Supabase.instance.client;

  Future<void> loadBusiness() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final data = await _supabase
        .from('businesses')
        .select()
        .eq('user_id', userId)
        .single();

    _business = BusinessModel.fromMap(data);
    _loading = false;
    notifyListeners();
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