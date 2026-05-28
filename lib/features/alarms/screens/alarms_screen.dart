import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/business_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/models/alarm_model.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  final _supabase = Supabase.instance.client;
  List<AlarmModel> _alarms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    final businessId = context.read<BusinessProvider>().business?.id;
    if (businessId == null) return;

    setState(() => _loading = true);
    final data = await _supabase
        .from('alarms')
        .select()
        .eq('business_id', businessId)
        .order('event_time');

    setState(() {
      _alarms = (data as List).map((e) => AlarmModel.fromMap(e)).toList();
      _loading = false;
    });
  }

  void _openForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AlarmForm(onSaved: _loadAlarms),
    );
  }

  Future<void> _deleteAlarm(AlarmModel alarm) async {
    try {
      await _supabase.from('alarms').delete().eq('id', alarm.id);
      await NotificationService.cancelAlarm(alarm.id.hashCode);
      _loadAlarms();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Alarmas y Recordatorios', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
          : _alarms.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _alarms.length,
                  itemBuilder: (context, index) {
                    final alarm = _alarms[index];
                    final isPast = alarm.eventTime.isBefore(DateTime.now());
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isPast ? Colors.grey.shade100 : Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: isPast ? Colors.grey : const Color(0xFFE8F5E9),
                          child: Icon(Icons.alarm, color: isPast ? Colors.white : const Color(0xFF2E7D32)),
                        ),
                        title: Text(
                          alarm.eventName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isPast ? TextDecoration.lineThrough : null,
                            color: isPast ? Colors.grey : Colors.black87,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(alarm.description, style: TextStyle(color: isPast ? Colors.grey : Colors.black54)),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('dd MMM yyyy, HH:mm').format(alarm.eventTime),
                              style: TextStyle(
                                color: isPast ? Colors.grey : const Color(0xFF1B5E20),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteAlarm(alarm),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alarm),
        label: const Text('Agregar alarma', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.alarm_off, size: 60, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 20),
          const Text('No tienes alarmas programadas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
          const SizedBox(height: 8),
          const Text('Presiona el botón para añadir un recordatorio.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _AlarmForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _AlarmForm({required this.onSaved});

  @override
  State<_AlarmForm> createState() => _AlarmFormState();
}

class _AlarmFormState extends State<_AlarmForm> {
  final _supabase = Supabase.instance.client;
  final _eventCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _saving = false;

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _selectedDate = date;
      _selectedTime = time;
    });
  }

  Future<void> _save() async {
    if (_eventCtrl.text.trim().isEmpty) {
      _snack('El nombre del evento es obligatorio', true);
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _snack('Debes seleccionar fecha y hora', true);
      return;
    }

    final eventDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    if (eventDateTime.isBefore(DateTime.now())) {
      _snack('La hora debe ser en el futuro', true);
      return;
    }

    setState(() => _saving = true);
    try {
      final businessId = context.read<BusinessProvider>().business!.id;
      final alarmData = {
        'business_id': businessId,
        'event_name': _eventCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'event_time': eventDateTime.toUtc().toIso8601String(),
        'is_active': true,
      };

      final data = await _supabase.from('alarms').insert(alarmData).select().single();
      final savedAlarm = AlarmModel.fromMap(data);

      await NotificationService.scheduleAlarm(
        id: savedAlarm.id.hashCode,
        title: savedAlarm.eventName,
        body: savedAlarm.description,
        scheduledDate: savedAlarm.eventTime,
      );

      if (mounted) Navigator.pop(context);
      widget.onSaved();
      _snack('✅ Alarma programada correctamente', false);
    } catch (e) {
      _snack('Error: $e', true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, bool isError) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : const Color(0xFF1B5E20),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final dateTimeText = _selectedDate != null && _selectedTime != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(
            DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute))
        : 'Seleccionar Fecha y Hora';

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 20),
          const Text('Nueva Alarma', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
          const SizedBox(height: 24),
          TextField(
            controller: _eventCtrl,
            decoration: InputDecoration(
              labelText: 'Nombre del evento',
              prefixIcon: const Icon(Icons.event_note, color: Color(0xFF2E7D32)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descCtrl,
            decoration: InputDecoration(
              labelText: 'Descripción (Opcional)',
              prefixIcon: const Icon(Icons.description, color: Color(0xFF2E7D32)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 12),
                  Text(dateTimeText, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Guardar Alarma', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
