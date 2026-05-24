import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/business_provider.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../../shared/models/purchase_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<PurchaseModel> _purchases = [];
  List<PurchaseModel> _filtered = [];
  bool _loading = true;

  // Filtro de fecha activo: 'today' | 'yesterday' | 'custom'
  String _dateFilter = 'today';
  DateTime? _customDate;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
    _searchController.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_dateFilter) {
      case 'yesterday':
        final y = now.subtract(const Duration(days: 1));
        // Convertimos al inicio del día en hora local, luego a UTC para Supabase
        return DateTime(y.year, y.month, y.day).toUtc();
      case 'custom':
        return _customDate != null
            ? DateTime(_customDate!.year, _customDate!.month, _customDate!.day).toUtc()
            : DateTime(now.year, now.month, now.day).toUtc();
      default: // 'today'
        return DateTime(now.year, now.month, now.day).toUtc();
    }
  }

  DateTime _getEndDate() {
    final start = _getStartDate();
    return start.add(const Duration(days: 1));
  }

  Future<void> _loadPurchases() async {
    setState(() => _loading = true);

    final business = context.read<BusinessProvider>().business;
    if (business == null) return;

    final data = await _supabase
        .from('purchases')
        .select()
        .eq('business_id', business.id)
        .gte('created_at', _getStartDate().toIso8601String())
        .lt('created_at', _getEndDate().toIso8601String())
        .order('created_at', ascending: false);

    final list =
        (data as List).map((e) => PurchaseModel.fromMap(e)).toList();

    setState(() {
      _purchases = list;
      _filtered = list;
      _loading = false;
    });

    // Re-aplicar búsqueda si hay texto
    if (_searchController.text.isNotEmpty) _applySearch();
  }

  void _applySearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _purchases
          : _purchases
              .where((p) => p.farmerName.toLowerCase().contains(query))
              .toList();
    });
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1B5E20),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customDate = picked;
        _dateFilter = 'custom';
      });
      _loadPurchases();
    }
  }

  // ── Métricas del período ──────────────────────────────────────

  double get _totalCash => _filtered
      .where((p) => p.status == 'active')
      .fold(0, (sum, p) => sum + p.totalPaid);

  double get _totalWeight => _filtered
      .where((p) => p.status == 'active')
      .fold(0, (sum, p) => sum + p.netWeight);

  int get _activeCount =>
      _filtered.where((p) => p.status == 'active').length;

  // ── Anular compra ──────────────────────────────────────────────

  Future<void> _cancelPurchase(PurchaseModel purchase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '⚠️ Anular compra',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de anular la compra de ${purchase.farmerName}?\n\n'
          'Esto restará \$${purchase.totalPaid.toStringAsFixed(2)} y '
          '${purchase.netWeight.toStringAsFixed(2)} ${purchase.weightUnit == 'quintales' ? 'QQ' : 'Lbs'} '
          'del resumen del día.'
          '${purchase.advanceDeducted > 0 ? '\n\nSe restaurará el adelanto descontado de \$${purchase.advanceDeducted.toStringAsFixed(2)}.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, anular'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Marcar la compra como cancelada
      await _supabase
          .from('purchases')
          .update({'status': 'cancelled'}).eq('id', purchase.id);

      // Si hubo adelanto descontado, restaurarlo en la tabla advances
      // Buscamos el adelanto más reciente del agricultor que fue descontado
      // y restauramos el monto (de forma conservadora: solo si el farmer_id existe)
      if (purchase.advanceDeducted > 0 && purchase.farmerId != null) {
        // Buscamos el adelanto 'fully_deducted' o 'active' más reciente del agricultor
        // y restauramos el monto que fue descontado
        final advances = await _supabase
            .from('advances')
            .select()
            .eq('farmer_id', purchase.farmerId!)
            .inFilter('status', ['active', 'fully_deducted'])
            .order('created_at', ascending: false)
            .limit(1);

        if ((advances as List).isNotEmpty) {
          final adv = advances.first;
          final currentRemaining = (adv['remaining'] as num).toDouble();
          final originalAmount = (adv['amount'] as num).toDouble();
          // Restaurar el monto descontado sin exceder el amount original
          final restored = (currentRemaining + purchase.advanceDeducted)
              .clamp(0.0, originalAmount);

          await _supabase.from('advances').update({
            'remaining': restored,
            'status': restored > 0 ? 'active' : 'fully_deducted',
          }).eq('id', adv['id']);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compra anulada correctamente'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadPurchases();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al anular: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Reenviar WhatsApp ─────────────────────────────────────────

  Future<void> _resendWhatsApp(PurchaseModel purchase) async {
    final business = context.read<BusinessProvider>().business;
    if (business == null) return;

    final wa = purchase.farmerWhatsapp;
    if (wa == null || wa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este agricultor no tiene número de WhatsApp guardado'),
        ),
      );
      return;
    }

    final message = WhatsAppHelper.buildReceiptMessage(
      business: business,
      purchase: purchase,
    );
    await WhatsAppHelper.sendReceipt(phoneNumber: wa, message: message);

    // Marcar como enviado si no lo estaba
    if (!purchase.whatsappSent) {
      await _supabase
          .from('purchases')
          .update({'whatsapp_sent': true}).eq('id', purchase.id);
      _loadPurchases();
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text(
          'Historial de Compras',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _buildFiltersSection(),
          _buildSummaryBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadPurchases,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _buildPurchaseTile(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Secciones ─────────────────────────────────────────────────

  Widget _buildFiltersSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Buscador
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar agricultor...',
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF2E7D32)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applySearch();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Pestañas de fecha
          Row(
            children: [
              _dateTab('Hoy', 'today'),
              const SizedBox(width: 8),
              _dateTab('Ayer', 'yesterday'),
              const SizedBox(width: 8),
              _dateTabCustom(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateTab(String label, String value) {
    final active = _dateFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _dateFilter = value);
        _loadPurchases();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1B5E20) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey.shade700,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _dateTabCustom() {
    final active = _dateFilter == 'custom';
    final label = active && _customDate != null
        ? DateFormat('d MMM', 'es').format(_customDate!)
        : 'Elegir fecha';

    return GestureDetector(
      onTap: _pickCustomDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1B5E20) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 14,
              color: active ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.grey.shade700,
                fontWeight:
                    active ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    final business = context.read<BusinessProvider>().business;
    final unit = business?.weightUnit == 'quintales' ? 'QQ' : 'Lbs';

    return Container(
      color: const Color(0xFFE8F5E9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem(
            label: 'Compras',
            value: '$_activeCount',
            icon: Icons.receipt_long,
          ),
          _divider(),
          _summaryItem(
            label: 'Peso neto',
            value:
                '${_totalWeight.toStringAsFixed(2)} $unit',
            icon: Icons.scale,
          ),
          _divider(),
          _summaryItem(
            label: 'Total pagado',
            value:
                '\$${NumberFormat('#,##0.00').format(_totalCash)}',
            icon: Icons.attach_money,
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF2E7D32)),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }

  Widget _divider() => Container(
        height: 32,
        width: 1,
        color: Colors.green.shade200,
      );

  // ── Tarjeta de compra ─────────────────────────────────────────

  Widget _buildPurchaseTile(PurchaseModel p) {
    final unit = p.weightUnit == 'quintales' ? 'QQ' : 'Lbs';
    final time = DateFormat('HH:mm').format(p.createdAt.toLocal());
    final isCancelled = p.status == 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCancelled ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isCancelled
            ? Border.all(color: Colors.red.shade200)
            : null,
        boxShadow: isCancelled
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          // ── Fila resumen ──────────────────────────────────────
          leading: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                time,
                style: TextStyle(
                  color: isCancelled
                      ? Colors.grey
                      : const Color(0xFF1B5E20),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          title: Text(
            p.farmerName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              decoration: isCancelled
                  ? TextDecoration.lineThrough
                  : null,
              color: isCancelled ? Colors.grey : Colors.black87,
            ),
          ),
          subtitle: Row(
            children: [
              Text(
                '${p.netWeight.toStringAsFixed(2)} $unit',
                style: TextStyle(
                  color: isCancelled ? Colors.grey : Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              if (isCancelled) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ANULADA',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${p.totalPaid.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCancelled
                      ? Colors.grey
                      : const Color(0xFF1B5E20),
                  decoration: isCancelled
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                p.whatsappSent
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: p.whatsappSent
                    ? const Color(0xFF25D366)
                    : Colors.grey,
                size: 16,
              ),
            ],
          ),
          // ── Detalle expandido ─────────────────────────────────
          children: [
            const Divider(),
            _detailRow('Peso bruto',
                '${p.grossWeight.toStringAsFixed(3)} $unit'),
            _detailRow(
              'Descuento (${p.discountType})',
              p.discountType == 'porcentaje'
                  ? '${p.discountValue.toStringAsFixed(1)}%'
                  : '${p.discountValue.toStringAsFixed(3)} $unit',
            ),
            _detailRow('Peso neto',
                '${p.netWeight.toStringAsFixed(3)} $unit'),
            _detailRow('Precio del día',
                '\$${p.pricePerUnit.toStringAsFixed(2)}'),
            _detailRow(
                'Subtotal', '\$${p.subtotal.toStringAsFixed(2)}'),
            if (p.advanceDeducted > 0)
              _detailRow('Adelanto descontado',
                  '-\$${p.advanceDeducted.toStringAsFixed(2)}'),
            _detailRow(
              'Total pagado',
              '\$${p.totalPaid.toStringAsFixed(2)}',
              bold: true,
            ),
            if (p.farmerWhatsapp != null)
              _detailRow('WhatsApp', p.farmerWhatsapp!),
            const SizedBox(height: 12),
            // Botones de acción (solo si no está anulada)
            if (!isCancelled) _buildDetailActions(p),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? const Color(0xFF1B5E20) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailActions(PurchaseModel p) {
    return Row(
      children: [
        // Reenviar WhatsApp
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _resendWhatsApp(p),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Reenviar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF25D366),
              side: const BorderSide(color: Color(0xFF25D366)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Anular
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _cancelPurchase(p),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Anular'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final label = _dateFilter == 'today'
        ? 'hoy'
        : _dateFilter == 'yesterday'
            ? 'ayer'
            : 'esta fecha';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Sin compras $label',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 18,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No hay resultados para "${_searchController.text}"',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
        ],
      ),
    );
  }
}
