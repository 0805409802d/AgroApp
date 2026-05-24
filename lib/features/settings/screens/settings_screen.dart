import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/business_provider.dart';
import '../../../core/utils/excel_helper.dart';
import '../../../shared/models/business_model.dart';
import '../../../shared/models/purchase_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;

  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _whatsappController = TextEditingController();

  bool _saving = false;
  bool _exporting = false;

  // Número de WhatsApp de soporte del administrador (para el botón "Contactar Soporte")
  static const _supportWhatsApp = '593980991658';

  @override
  void initState() {
    super.initState();
    _prefillFields();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  void _prefillFields() {
    final business = context.read<BusinessProvider>().business;
    if (business == null) return;
    _businessNameController.text = business.businessName;
    _ownerNameController.text = business.ownerName ?? '';
    _whatsappController.text = business.whatsappNumber ?? '';
  }

  Future<void> _saveSettings({
    required String weightUnit,
    required String discountType,
  }) async {
    final business = context.read<BusinessProvider>().business;
    final businessProvider = context.read<BusinessProvider>();

    setState(() => _saving = true);
    try {
      if (business == null) {
        // Insert new business
        final userId = _supabase.auth.currentUser!.id;
        await _supabase.from('businesses').insert({
          'user_id': userId,
          'business_name': _businessNameController.text.trim(),
          'owner_name': _ownerNameController.text.trim(),
          'whatsapp_number': _whatsappController.text.trim(),
          'product_type': 'cacao', // Default product type
          'weight_unit': weightUnit,
          'discount_type': discountType,
          'current_price': 0.00,
          'is_active': false,
        });
      } else {
        // Update existing business
        await _supabase.from('businesses').update({
          'business_name': _businessNameController.text.trim(),
          'owner_name': _ownerNameController.text.trim(),
          'whatsapp_number': _whatsappController.text.trim(),
          'weight_unit': weightUnit,
          'discount_type': discountType,
        }).eq('id', business.id);
      }

      await businessProvider.loadBusiness();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configuración guardada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportExcel(String period) async {
    final business = context.read<BusinessProvider>().business;
    if (business == null) return;

    setState(() => _exporting = true);

    try {
      DateTime startDate;
      DateTime endDate = DateTime.now();
      String periodLabel;

      final now = DateTime.now();

      switch (period) {
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          // Inicio del día hace 7 días en hora local → UTC
          startDate = DateTime(startDate.year, startDate.month, startDate.day).toUtc();
          endDate = DateTime(now.year, now.month, now.day + 1).toUtc(); // fin del día hoy
          periodLabel =
              '${DateFormat('dd-MM').format(startDate.toLocal())}_al_${DateFormat('dd-MM-yyyy').format(now)}';
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1).toUtc();
          endDate = DateTime(now.year, now.month + 1, 1).toUtc();
          periodLabel = DateFormat('MMMM_yyyy', 'es').format(now);
          break;
        case 'last_month':
          final lm = DateTime(now.year, now.month - 1, 1);
          startDate = DateTime(lm.year, lm.month, 1).toUtc();
          endDate = DateTime(now.year, now.month, 1).toUtc();
          periodLabel = DateFormat('MMMM_yyyy', 'es').format(lm);
          break;
        default: // 'today'
          startDate = DateTime(now.year, now.month, now.day).toUtc();
          endDate = DateTime(now.year, now.month, now.day + 1).toUtc();
          periodLabel = DateFormat('dd-MM-yyyy').format(now);
      }

      final data = await _supabase
          .from('purchases')
          .select()
          .eq('business_id', business.id)
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false);

      final purchases =
          (data as List).map((e) => PurchaseModel.fromMap(e)).toList();

      if (purchases.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay compras en este período'),
            ),
          );
        }
        return;
      }

      await ExcelHelper.exportPurchases(
        purchases: purchases,
        business: business,
        periodLabel: periodLabel,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openSupport() async {
    const message =
        'Hola, necesito ayuda con AgroApp 🌱';
    final encoded = Uri.encodeComponent(message);
    final url =
        'https://wa.me/$_supportWhatsApp?text=$encoded';
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  void _showExportDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Descargar reporte Excel',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Elige el período a exportar',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _exportOption(
              icon: Icons.today,
              label: 'Hoy',
              subtitle: 'Solo las compras de hoy',
              period: 'today',
            ),
            _exportOption(
              icon: Icons.date_range,
              label: 'Últimos 7 días',
              subtitle: 'Semana en curso',
              period: 'week',
            ),
            _exportOption(
              icon: Icons.calendar_month,
              label: 'Este mes',
              subtitle:
                  DateFormat('MMMM yyyy', 'es').format(DateTime.now()),
              period: 'month',
            ),
            _exportOption(
              icon: Icons.history,
              label: 'Mes anterior',
              subtitle: DateFormat('MMMM yyyy', 'es').format(
                DateTime(
                    DateTime.now().year, DateTime.now().month - 1),
              ),
              period: 'last_month',
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _exportOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required String period,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF1B5E20)),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.download, color: Color(0xFF1B5E20)),
      onTap: () {
        Navigator.pop(context);
        _exportExcel(period);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();
    final business = provider.business;

    if (provider.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _SettingsForm(
      business: business, // Puede ser null
      businessNameController: _businessNameController,
      ownerNameController: _ownerNameController,
      whatsappController: _whatsappController,
      saving: _saving,
      exporting: _exporting,
      onSave: _saveSettings,
      onExport: _showExportDialog,
      onSupport: _openSupport,
      onLogout: () async {
        await _supabase.auth.signOut();
        // ignore: use_build_context_synchronously
        if (mounted) context.go('/login');
      },
    );
  }
}

// ── Formulario separado para mantener el State limpio ────────

class _SettingsForm extends StatefulWidget {
  final BusinessModel? business;
  final TextEditingController businessNameController;
  final TextEditingController ownerNameController;
  final TextEditingController whatsappController;
  final bool saving;
  final bool exporting;
  final Future<void> Function({
    required String weightUnit,
    required String discountType,
  }) onSave;
  final VoidCallback onExport;
  final VoidCallback onSupport;
  final VoidCallback onLogout;

  const _SettingsForm({
    required this.business,
    required this.businessNameController,
    required this.ownerNameController,
    required this.whatsappController,
    required this.saving,
    required this.exporting,
    required this.onSave,
    required this.onExport,
    required this.onSupport,
    required this.onLogout,
  });

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  late String _weightUnit;
  late String _discountType;

  @override
  void initState() {
    super.initState();
    _weightUnit = widget.business?.weightUnit ?? 'quintales';
    _discountType = widget.business?.discountType ?? 'porcentaje';
  }

  @override
  Widget build(BuildContext context) {
    final expiry = widget.business?.subscriptionExpiresAt;
    final isActive = widget.business?.isActive ?? false;
    final expiryLabel = expiry != null
        ? DateFormat('d \'de\' MMMM yyyy', 'es').format(expiry)
        : 'Sin fecha registrada';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text(
          'Configuración',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Perfil del negocio ──────────────────────────
            _sectionCard(
              title: 'Perfil del negocio',
              icon: Icons.store,
              child: Column(
                children: [
                  _buildField(
                    widget.businessNameController,
                    'Nombre del negocio',
                    Icons.storefront,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    widget.ownerNameController,
                    'Nombre del comerciante',
                    Icons.person,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── WhatsApp para recibos ─────────────────────
            _sectionCard(
              title: 'Mi número de WhatsApp',
              icon: Icons.chat,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Este es el número desde el cual se abrirá WhatsApp al enviar un recibo a un cliente. Debe ser tu número con código de país (Ej: 593981234567).',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    widget.whatsappController,
                    'Tu número de WhatsApp',
                    Icons.phone,
                    type: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Al presionar "Enviar WhatsApp" en una compra, se abrirá desde este número al número del vendedor.',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Preferencias ────────────────────────────────
            _sectionCard(
              title: 'Preferencias del sistema',
              icon: Icons.tune,
              child: Column(
                children: [
                  _buildSelector(
                    label: 'Unidad de peso predeterminada',
                    options: const {
                      'quintales': 'Quintales (QQ)',
                      'libras': 'Libras (Lbs)',
                    },
                    selected: _weightUnit,
                    onChanged: (v) =>
                        setState(() => _weightUnit = v),
                  ),
                  const SizedBox(height: 16),
                  _buildSelector(
                    label: 'Tipo de descuento predeterminado',
                    options: const {
                      'porcentaje': 'Porcentaje (%)',
                      'libras': 'Libras / Unidad',
                    },
                    selected: _discountType,
                    onChanged: (v) =>
                        setState(() => _discountType = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Exportar ─────────────────────────────────────
            if (widget.business != null)
              _sectionCard(
                title: 'Exportar datos',
                icon: Icons.download,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Descarga tus compras en Excel para cuadrar cuentas con tu contador.',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: widget.exporting
                          ? null
                          : widget.onExport,
                      icon: widget.exporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.table_chart),
                      label: Text(
                        widget.exporting
                            ? 'Generando...'
                            : 'Descargar Reporte Excel',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Suscripción y soporte ─────────────────────────
            if (widget.business != null)
              _sectionCard(
                title: 'Suscripción y soporte',
                icon: Icons.support_agent,
                child: Column(
                  children: [
                    // Estado suscripción
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    child: Row(
                      children: [
                        Icon(
                          isActive
                              ? Icons.check_circle
                              : Icons.warning,
                          color: isActive
                              ? const Color(0xFF1B5E20)
                              : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                isActive
                                    ? 'Plan Activo ✅'
                                    : 'Plan Inactivo ⚠️',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? const Color(0xFF1B5E20)
                                      : Colors.red,
                                ),
                              ),
                              Text(
                                'Próximo pago: $expiryLabel',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Botón soporte
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: widget.onSupport,
                      icon: const Icon(Icons.chat),
                      label: const Text(
                        'Contactar Soporte (WhatsApp)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Botón guardar ────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: widget.saving
                    ? null
                    : () => widget.onSave(
                          weightUnit: _weightUnit,
                          discountType: _discountType,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: widget.saving
                    ? const CircularProgressIndicator(
                        color: Colors.white)
                    : const Text(
                        'Guardar cambios',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Cerrar sesión ────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF2E7D32),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildSelector({
    required String label,
    required Map<String, String> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: options.entries.map((entry) {
            final active = selected == entry.key;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: Container(
                  margin: EdgeInsets.only(
                    right: entry.key == options.keys.first ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF1B5E20)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF1B5E20)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : Colors.grey.shade700,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
