import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/business_provider.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../../shared/models/farmer_model.dart';
import '../../../shared/models/purchase_model.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final _supabase = Supabase.instance.client;

  // Controllers
  final _farmerNameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _grossWeightController = TextEditingController();
  final _discountValueController = TextEditingController();
  final _advanceController = TextEditingController();

  // Estado
  List<FarmerModel> _allFarmers = [];
  List<FarmerModel> _filteredFarmers = [];
  bool _showSuggestions = false;
  String _discountMode = 'porcentaje'; // 'porcentaje' | 'libras'
  bool _saving = false;

  // Calculados en tiempo real
  double _netWeight = 0;
  double _subtotal = 0;
  double _totalPaid = 0;

  @override
  void initState() {
    super.initState();
    _loadFarmers();
    _loadDefaultDiscountMode();
    _grossWeightController.addListener(_recalculate);
    _discountValueController.addListener(_recalculate);
    _advanceController.addListener(_recalculate);
  }

  @override
  void dispose() {
    _farmerNameController.dispose();
    _whatsappController.dispose();
    _grossWeightController.dispose();
    _discountValueController.dispose();
    _advanceController.dispose();
    super.dispose();
  }

  void _loadDefaultDiscountMode() {
    final business = context.read<BusinessProvider>().business;
    if (business != null) {
      setState(() => _discountMode = business.discountType);
    }
  }

  Future<void> _loadFarmers() async {
    final business = context.read<BusinessProvider>().business;
    if (business == null) return;

    final data = await _supabase
        .from('farmers')
        .select()
        .eq('business_id', business.id)
        .order('name');

    setState(() {
      _allFarmers = (data as List).map((e) => FarmerModel.fromMap(e)).toList();
    });
  }

  void _onFarmerNameChanged(String value) {
    if (value.length < 2) {
      setState(() => _showSuggestions = false);
      return;
    }
    final filtered = _allFarmers
        .where((f) => f.name.toLowerCase().contains(value.toLowerCase()))
        .take(5)
        .toList();
    setState(() {
      _filteredFarmers = filtered;
      _showSuggestions = filtered.isNotEmpty;
    });
  }

  void _selectFarmer(FarmerModel farmer) {
    _farmerNameController.text = farmer.name;
    _whatsappController.text = farmer.whatsappNumber ?? '';
    setState(() => _showSuggestions = false);
  }

  void _recalculate() {
    final business = context.read<BusinessProvider>().business;
    if (business == null) return;

    final gross = double.tryParse(
            _grossWeightController.text.replaceAll(',', '.')) ??
        0;
    final discountVal = double.tryParse(
            _discountValueController.text.replaceAll(',', '.')) ??
        0;
    final advance =
        double.tryParse(_advanceController.text.replaceAll(',', '.')) ?? 0;

    double net;
    if (_discountMode == 'porcentaje') {
      net = gross - (gross * discountVal / 100);
    } else {
      net = gross - discountVal;
    }
    if (net < 0) net = 0;

    final sub = net * business.currentPrice;
    final total = sub - advance;

    setState(() {
      _netWeight = net;
      _subtotal = sub;
      _totalPaid = total < 0 ? 0 : total;
    });
  }

  Future<void> _savePurchase({required bool sendWhatsApp}) async {
    final business = context.read<BusinessProvider>().business;
    if (business == null) return;

    final farmerName = _farmerNameController.text.trim();
    if (farmerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre del agricultor')),
      );
      return;
    }

    final gross = double.tryParse(
        _grossWeightController.text.replaceAll(',', '.')) ?? 0;
    if (gross <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el peso bruto')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Guardar o actualizar agricultor
      String? farmerId;
      final existing = _allFarmers.where(
        (f) => f.name.toLowerCase() == farmerName.toLowerCase(),
      );

      if (existing.isNotEmpty) {
        farmerId = existing.first.id;
        // Actualizar whatsapp si se ingresó uno nuevo
        final wa = _whatsappController.text.trim();
        if (wa.isNotEmpty && existing.first.whatsappNumber != wa) {
          await _supabase
              .from('farmers')
              .update({'whatsapp_number': wa}).eq('id', farmerId);
        }
      } else {
        // Cliente nuevo
        final newFarmer = await _supabase
            .from('farmers')
            .insert({
              'business_id': business.id,
              'name': farmerName,
              'whatsapp_number': _whatsappController.text.trim().isEmpty
                  ? null
                  : _whatsappController.text.trim(),
            })
            .select()
            .single();
        farmerId = newFarmer['id'];
      }

      final discountVal = double.tryParse(
              _discountValueController.text.replaceAll(',', '.')) ?? 0;
      final advance =
          double.tryParse(_advanceController.text.replaceAll(',', '.')) ?? 0;

      // Insertar compra
      final insertData = {
        'business_id': business.id,
        'farmer_id': farmerId,
        'farmer_name': farmerName,
        'farmer_whatsapp': _whatsappController.text.trim().isEmpty
            ? null
            : _whatsappController.text.trim(),
        'gross_weight': gross,
        'discount_type': _discountMode,
        'discount_value': discountVal,
        'net_weight': _netWeight,
        'weight_unit': business.weightUnit,
        'price_per_unit': business.currentPrice,
        'subtotal': _subtotal,
        'advance_deducted': advance,
        'total_paid': _totalPaid,
        'status': 'active',
        'whatsapp_sent': sendWhatsApp,
      };

      final savedPurchase = await _supabase
          .from('purchases')
          .insert(insertData)
          .select()
          .single();

      final purchase = PurchaseModel.fromMap(savedPurchase);

      if (sendWhatsApp) {
        final wa = _whatsappController.text.trim();
        if (wa.isNotEmpty) {
          final message = WhatsAppHelper.buildReceiptMessage(
            business: business,
            purchase: purchase,
          );
          await WhatsAppHelper.sendReceipt(
            phoneNumber: wa,
            message: message,
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Compra guardada. No hay número de WhatsApp para enviar.',
                ),
              ),
            );
          }
        }
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>().business;
    final unit = business?.weightUnit == 'quintales' ? 'QQ' : 'Lbs';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text(
          'Nueva Compra',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        // Precio del día visible en el AppBar
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '\$${business?.currentPrice.toStringAsFixed(2)} / $unit',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFarmerSection(),
            const SizedBox(height: 16),
            _buildWeightSection(unit),
            const SizedBox(height: 16),
            _buildAdvanceSection(),
            const SizedBox(height: 16),
            _buildTotalCard(),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Secciones ────────────────────────────────────────────────

  Widget _buildFarmerSection() {
    return _sectionCard(
      title: 'Agricultor',
      icon: Icons.person,
      child: Column(
        children: [
          TextField(
            controller: _farmerNameController,
            onChanged: _onFarmerNameChanged,
            textCapitalization: TextCapitalization.words,
            decoration: _fieldDecoration('Nombre del agricultor *'),
          ),
          // Sugerencias autocomplete
          if (_showSuggestions)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _filteredFarmers.map((f) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline,
                        color: Color(0xFF2E7D32)),
                    title: Text(f.name),
                    subtitle: f.whatsappNumber != null
                        ? Text(f.whatsappNumber!)
                        : null,
                    onTap: () => _selectFarmer(f),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            decoration: _fieldDecoration(
              'WhatsApp (opcional)',
              hint: 'Ej: 0991234567',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightSection(String unit) {
    return _sectionCard(
      title: 'Pesaje',
      icon: Icons.scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _grossWeightController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: _fieldDecoration(
              'Peso Bruto ($unit)',
              hint: '0.00',
            ),
          ),
          const SizedBox(height: 16),
          // Toggle porcentaje / libras
          const Text(
            'Tipo de descuento',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _toggleButton(
                  label: '% Porcentaje',
                  active: _discountMode == 'porcentaje',
                  onTap: () {
                    setState(() => _discountMode = 'porcentaje');
                    _recalculate();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _toggleButton(
                  label: 'Libras / $unit',
                  active: _discountMode == 'libras',
                  onTap: () {
                    setState(() => _discountMode = 'libras');
                    _recalculate();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _discountValueController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _fieldDecoration(
              _discountMode == 'porcentaje'
                  ? 'Descuento (%)'
                  : 'Descuento ($unit)',
              hint: '0',
            ),
          ),
          const SizedBox(height: 12),
          // Peso neto en tiempo real
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Peso Neto: ${_netWeight.toStringAsFixed(3)} $unit',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvanceSection() {
    return _sectionCard(
      title: 'Adelantos',
      icon: Icons.payments_outlined,
      child: TextField(
        controller: _advanceController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _fieldDecoration(
          'Descontar adelanto (\$)',
          hint: '0.00 — dejar vacío si no hay',
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'TOTAL A PAGAR',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${_totalPaid.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (_advanceController.text.isNotEmpty &&
              (_advanceController.text != '0'))
            Text(
              'Subtotal \$${_subtotal.toStringAsFixed(2)} — Adelanto \$${(double.tryParse(_advanceController.text) ?? 0).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Botón primario: Guardar + WhatsApp
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : () => _savePurchase(sendWhatsApp: true),
            icon: const Icon(Icons.send, size: 24),
            label: const Text(
              'Guardar y Enviar WhatsApp',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366), // verde WhatsApp
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Botón secundario: Solo guardar
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed:
                _saving ? null : () => _savePurchase(sendWhatsApp: false),
            icon: const Icon(Icons.save_outlined),
            label: const Text(
              'Solo Guardar (Sin Mensaje)',
              style: TextStyle(fontSize: 16),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1B5E20),
              side: const BorderSide(color: Color(0xFF1B5E20), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        if (_saving)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  // ── Helpers de UI ────────────────────────────────────────────

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
            color: Colors.black.withOpacity(0.05),
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

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: Color(0xFF2E7D32), width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _toggleButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1B5E20) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFF1B5E20) : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.grey.shade700,
              fontWeight:
                  active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}