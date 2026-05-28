import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/globals.dart';
import '../../../shared/models/alarm_model.dart';

class WebAlarmService {
  static final WebAlarmService _instance = WebAlarmService._internal();
  factory WebAlarmService() => _instance;
  WebAlarmService._internal();

  final _supabase = Supabase.instance.client;
  final Map<String, Timer> _activeTimers = {};
  String? _businessId;
  StreamSubscription? _alarmsSub;

  void initialize(String businessId) {
    if (!kIsWeb) return; // Solo ejecutar lógica en Web
    
    _businessId = businessId;
    _loadAndListenAlarms();
  }

  void _loadAndListenAlarms() {
    _alarmsSub?.cancel();
    
    _alarmsSub = _supabase
        .from('alarms')
        .stream(primaryKey: ['id'])
        .eq('business_id', _businessId!)
        .listen((data) {
          final alarms = data.map((e) => AlarmModel.fromMap(e)).toList();
          _scheduleAlarms(alarms);
        });
  }

  void _scheduleAlarms(List<AlarmModel> alarms) {
    // Cancelar timers que ya no existen o han sido desactivados
    final newIds = alarms.map((e) => e.id).toSet();
    _activeTimers.keys.where((id) => !newIds.contains(id)).toList().forEach((id) {
      _activeTimers[id]?.cancel();
      _activeTimers.remove(id);
    });

    for (var alarm in alarms) {
      if (!alarm.isActive) {
        _activeTimers[alarm.id]?.cancel();
        _activeTimers.remove(alarm.id);
        continue;
      }

      final now = DateTime.now();
      if (alarm.eventTime.isBefore(now)) continue; // Ya pasó

      // Si ya está programada, la ignoramos (a menos que haya cambiado el tiempo, pero para simplificar asumimos que si existe está bien)
      if (_activeTimers.containsKey(alarm.id)) continue;

      final duration = alarm.eventTime.difference(now);
      
      _activeTimers[alarm.id] = Timer(duration, () {
        _showAlarmModal(alarm);
        _activeTimers.remove(alarm.id);
        
        // Opcional: Marcar como inactiva en la BD después de sonar
        _supabase.from('alarms').update({'is_active': false}).eq('id', alarm.id);
      });
    }
  }

  void _showAlarmModal(AlarmModel alarm) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false, // El usuario debe presionar la X obligatoriamente
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.alarm_on, color: Colors.green, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text('¡Alarma: ${alarm.eventName}!', style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(alarm.description, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(ctx).pop(),
            icon: const Icon(Icons.close, color: Colors.red),
            label: const Text('Cerrar Alarma', style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  void dispose() {
    _alarmsSub?.cancel();
    for (var timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
  }
}
