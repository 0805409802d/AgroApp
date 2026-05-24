import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/models/dashboard_alert_model.dart';

class DashboardProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<DashboardAlertModel> _alerts = [];
  bool _loading = false;

  List<DashboardAlertModel> get alerts => _alerts;
  bool get loading => _loading;

  Future<void> loadAlerts(String businessId) async {
    _loading = true;
    notifyListeners();

    try {
      final response = await _supabase.rpc('get_dashboard_alerts', params: {
        'p_business_id': businessId,
      });

      if (response != null) {
        final List<dynamic> alertsList = response as List<dynamic>;
        _alerts = alertsList
            .map((e) => DashboardAlertModel.fromMap(e as Map<String, dynamic>))
            .toList();
      } else {
        _alerts = [];
      }
    } catch (e) {
      _alerts = [];
    }

    _loading = false;
    notifyListeners();
  }
}