// lib/features/employees/screens/employees_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/business_provider.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final businessId = context.read<BusinessProvider>().business?.id;
    if (businessId == null) return;

    setState(() => _loading = true);
    final data = await _supabase
        .from('employees')
        .select()
        .eq('business_id', businessId)
        .order('created_at');

    setState(() {
      _employees = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  // Abre el modal para crear o editar un empleado
  void _openForm({Map<String, dynamic>? employee}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EmployeeForm(
        employee: employee,
        onSaved: _loadEmployees,
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> emp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar personal'),
        content: Text(
          '¿Seguro que deseas eliminar a "${emp['name']}"?\nEsta persona ya no podrá acceder a la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.functions.invoke('delete-employee', body: {
        'employeeUserId': emp['user_id'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Personal eliminado correctamente'),
            backgroundColor: Color(0xFF1B5E20),
          ),
        );
      }
      await _loadEmployees();
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
        title: const Text(
          'Personal de Trabajo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)))
          : _employees.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _employees.length,
                  itemBuilder: (context, index) =>
                      _EmployeeCard(
                        employee: _employees[index],
                        onEdit: () => _openForm(employee: _employees[index]),
                        onDelete: () => _confirmDelete(_employees[index]),
                      ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text(
          'Crear nuevo personal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
            child: const Icon(Icons.group_outlined, size: 60, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Aún no tienes personal registrado',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Presiona el botón verde para agregar\na tu primer empleado.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Tarjeta de empleado ──────────────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EmployeeCard({
    required this.employee,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = employee['name'] as String? ?? 'Sin nombre';
    final isActive = employee['is_active'] as bool? ?? true;
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((e) => e[0].toUpperCase()).join()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: isActive ? const Color(0xFF2E7D32) : Colors.grey,
          child: Text(
            initials,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFE8F5E9) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isActive ? 'Activo' : 'Inactivo',
                style: TextStyle(
                  color: isActive ? const Color(0xFF2E7D32) : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.edit_outlined, color: Color(0xFF1B5E20)),
                title: Text('Editar'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Eliminar', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Formulario de crear / editar empleado ────────────────────────────────────

class _EmployeeForm extends StatefulWidget {
  final Map<String, dynamic>? employee;
  final VoidCallback onSaved;

  const _EmployeeForm({this.employee, required this.onSaved});

  @override
  State<_EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<_EmployeeForm> {
  final _supabase = Supabase.instance.client;
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _saving = false;
  bool _showPassword = false;

  bool get isEditing => widget.employee != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final parts = (widget.employee!['name'] as String? ?? '').split(' ');
      _firstNameCtrl.text = parts.isNotEmpty ? parts[0] : '';
      _lastNameCtrl.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstNameCtrl.text.trim().isEmpty) {
      _snack('El nombre es obligatorio', error: true);
      return;
    }
    if (!isEditing && _emailCtrl.text.trim().isEmpty) {
      _snack('El correo es obligatorio', error: true);
      return;
    }
    if (!isEditing && _passwordCtrl.text.length < 6) {
      _snack('La contraseña debe tener al menos 6 caracteres', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      if (isEditing) {
        // Solo actualizar el nombre en la tabla employees
        final name = '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
        await _supabase
            .from('employees')
            .update({'name': name})
            .eq('user_id', widget.employee!['user_id']);
        _snack('✅ Datos actualizados correctamente');
      } else {
        // Crear nuevo empleado via Edge Function
        final res = await _supabase.functions.invoke('create-employee', body: {
          'firstName': _firstNameCtrl.text.trim(),
          'lastName': _lastNameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
        });

        if (res.status != 200) {
          final msg = (res.data as Map?)?['error'] ?? 'Error desconocido';
          _snack(msg, error: true);
          return;
        }
        _snack('✅ Personal creado correctamente');
      }

      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : const Color(0xFF1B5E20),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isEditing ? 'Editar personal' : 'Crear nuevo personal',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isEditing
                ? 'Actualiza los datos de este empleado.'
                : 'Completa los datos para dar acceso a la app.',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Nombre
          _field(
            controller: _firstNameCtrl,
            label: 'Nombre',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),

          // Apellido
          _field(
            controller: _lastNameCtrl,
            label: 'Apellido',
            icon: Icons.person_outline,
          ),

          if (!isEditing) ...[
            const SizedBox(height: 14),
            _field(
              controller: _emailCtrl,
              label: 'Correo electrónico',
              icon: Icons.email_outlined,
              type: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordCtrl,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF2E7D32)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Botón guardar
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      isEditing ? 'Guardar cambios' : 'Crear empleado',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
      ),
    );
  }
}
