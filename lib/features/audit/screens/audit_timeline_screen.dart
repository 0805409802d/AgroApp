import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/services/business_provider.dart';

class AuditTimelineScreen extends StatefulWidget {
  const AuditTimelineScreen({super.key});

  @override
  State<AuditTimelineScreen> createState() => _AuditTimelineScreenState();
}

class _AuditTimelineScreenState extends State<AuditTimelineScreen> {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchLogs() async {
    final businessId = context.read<BusinessProvider>().business?.id;
    if (businessId == null) return [];

    // Nota: la relación auth_users dependerá de cómo se llame en Supabase o
    // puede requerir una vista, pero asumimos el email si está expuesto.
    // Como alternativa, podemos cruzar con la tabla `employees`
    final response = await _supabase
        .from('audit_logs')
        .select('''
          *,
          users_view:user_id(email)
        ''')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(100);
        
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Odín (Auditoría)'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Manejo silencioso en UI de la vista de usuarios (si falla RLS)
            return Center(child: Text('Error al cargar logs: ${snapshot.error}'));
          }
          
          final logs = snapshot.data ?? [];
          
          if (logs.isEmpty) {
            return const Center(child: Text('No hay eventos registrados aún.'));
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final date = DateTime.parse(log['created_at']).toLocal();
              final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);
              
              // Intentar sacar email si está disponible
              final userEmail = log['users_view']?['email'] ?? log['user_id'] ?? 'Sistema';
              final action = log['action_type'];
              final entity = log['entity_name'];

              // Logic to make it human readable
              String humanReadable = 'Usuario realizó un $action en $entity';
              if (action == 'INSERT' && entity == 'purchases') {
                humanReadable = 'Nueva compra registrada';
              } else if (action == 'UPDATE' && entity == 'businesses') {
                humanReadable = 'Configuración del negocio modificada';
              } else if (entity == 'cash_sessions') {
                humanReadable = 'Caja interactuada ($action)';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: action == 'DELETE' ? Colors.red.shade100 : Colors.green.shade100,
                    child: Icon(
                      action == 'INSERT' ? Icons.add :
                      action == 'UPDATE' ? Icons.edit : Icons.delete,
                      color: action == 'DELETE' ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(humanReadable, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Autor: $userEmail\n$formattedDate'),
                  isThreeLine: true,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Detalle Técnico'),
                        content: SingleChildScrollView(
                          child: Text('ID Entidad: ${log['entity_id']}\nData Nueva:\n${log['new_data']}\nData Previa:\n${log['previous_data']}'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cerrar'),
                          )
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
