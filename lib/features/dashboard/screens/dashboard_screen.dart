// DashboardScreen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/business_provider.dart';
import '../../../shared/models/business_model.dart';
import '../../../shared/models/purchase_model.dart';
import '../../../shared/widgets/offline_status_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;
  List<PurchaseModel> _todayPurchases = [];
  bool _loadingPurchases = true;

  // Métricas del día
  double _totalCashPaid = 0;
  double _totalNetWeight = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final provider = context.read<BusinessProvider>();
    await provider.loadBusiness();
    await _loadTodayPurchases();
  }

  Future<void> _loadTodayPurchases() async {
    final business = context.read<BusinessProvider>().business;
    if (business == null) return;

    final now = DateTime.now();
    // Inicio del día en hora local (Ecuador UTC-5), convertido a UTC para Supabase
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc();

    final data = await _supabase
        .from('purchases')
        .select()
        .eq('business_id', business.id)
        .eq('status', 'active')
        .gte('created_at', startOfDay.toIso8601String())
        .order('created_at', ascending: false);

    final purchases = (data as List)
        .map((e) => PurchaseModel.fromMap(e))
        .toList();

    double cash = 0;
    double weight = 0;
    for (final p in purchases) {
      cash += p.totalPaid;
      weight += p.netWeight;
    }

    setState(() {
      _todayPurchases = purchases;
      _totalCashPaid = cash;
      _totalNetWeight = weight;
      _loadingPurchases = false;
    });
  }

  void _showPriceEditor(BuildContext context, double currentPrice) {
    final controller =
        TextEditingController(text: currentPrice.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actualizar precio del día',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                prefixStyle:
                    TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
                labelText: 'Precio por quintal',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final newPrice =
                      double.tryParse(controller.text.replaceAll(',', '.'));
                  if (newPrice != null && newPrice > 0) {
                    await context.read<BusinessProvider>().updatePrice(newPrice);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Guardar precio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatWeight(double weight, String unit) {
    final formatted = weight % 1 == 0
        ? weight.toInt().toString()
        : weight.toStringAsFixed(2);
    return '$formatted ${unit == 'quintales' ? 'QQ' : 'Lbs'}';
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

    // Cuenta bloqueada
    if (business != null && !business.isActive) {
      return _buildInactiveScreen(business.businessName);
    }

    // Negocio nulo (no completado)
    if (business == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.store_mall_directory_outlined, size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                const Text(
                  'Configuración incompleta',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Falta crear la configuración de tu negocio. Por favor, ve a Ajustes para completarla.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings),
                  label: const Text('Ir a Ajustes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    final router = GoRouter.of(context);
                    await _supabase.auth.signOut();
                    if (mounted) router.go('/login');
                  },
                  child: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTodayPurchases,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(business),
                const SizedBox(height: 16),
                _buildPriceCard(business),
                const SizedBox(height: 16),
                _buildNewPurchaseButton(context),
                const SizedBox(height: 16),
                _buildDailySummary(business),
                const SizedBox(height: 16),
                _buildRecentTransactions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets internos ──────────────────────────────────────────

  Widget _buildTopBar(BusinessModel? business) {
    final today = DateFormat('EEEE d MMM', 'es').format(DateTime.now());
    final isAdmin = context.read<BusinessProvider>().isAdmin;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              business?.businessName ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            Text(
              today,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        Row(
          children: [
            const OfflineStatusWidget(),
            const SizedBox(width: 8),
            if (isAdmin) ...[
              IconButton(
                icon: const Icon(Icons.folder_shared_outlined),
                onPressed: () => context.push('/file_manager'),
                tooltip: 'Base de Datos',
              ),
              IconButton(
                icon: const Icon(Icons.access_time),
                onPressed: () => context.push('/alarms'),
                tooltip: 'Alarmas',
              ),
            ],
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await _supabase.auth.signOut();
                if (mounted) context.go('/login');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceCard(BusinessModel? business) {
    if (business == null) return const SizedBox();
    final unit = business.weightUnit == 'quintales' ? 'Quintal' : 'Libra';
    final product = business.productType[0].toUpperCase() +
        business.productType.substring(1);
    final isAdmin = context.read<BusinessProvider>().isAdmin;

    return GestureDetector(
      onTap: isAdmin ? () => _showPriceEditor(context, business.currentPrice) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E20),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Precio del día - $product',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${business.currentPrice.toStringAsFixed(2)} / $unit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (isAdmin) const Icon(Icons.edit, color: Colors.white70, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildNewPurchaseButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: ElevatedButton.icon(
        onPressed: () async {
          await context.push('/purchase');
          // Al volver, recargamos las métricas
          _loadTodayPurchases();
        },
        icon: const Icon(Icons.add_circle_outline, size: 32),
        label: const Text(
          'NUEVA COMPRA',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildDailySummary(BusinessModel? business) {
    if (business == null) return const SizedBox();
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            icon: Icons.attach_money,
            label: 'Efectivo entregado',
            value:
                '\$${NumberFormat('#,##0.00').format(_totalCashPaid)}',
            color: const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            icon: Icons.scale,
            label: 'Peso neto comprado',
            value: _formatWeight(_totalNetWeight, business.weightUnit),
            color: const Color(0xFF6A1B9A),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
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
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final last3 = _todayPurchases.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Últimas compras',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => context.push('/history'),
              child: const Text('Ver todo'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingPurchases)
          const Center(child: CircularProgressIndicator())
        else if (last3.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Sin compras hoy aún.\n¡Presiona NUEVA COMPRA!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...last3.map((p) => _transactionTile(p)),
      ],
    );
  }

  Widget _transactionTile(PurchaseModel p) {
    final unit = p.weightUnit == 'quintales' ? 'QQ' : 'Lbs';
    final time = DateFormat('HH:mm').format(p.createdAt.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Hora
          Text(
            time,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(width: 12),
          // Nombre y peso
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.farmerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${p.netWeight.toStringAsFixed(2)} $unit',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          // Total
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${p.totalPaid.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1B5E20),
                ),
              ),
              Icon(
                p.whatsappSent ? Icons.check_circle : Icons.circle_outlined,
                color: p.whatsappSent ? Colors.green : Colors.grey,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveScreen(String businessName) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_clock, color: Colors.white, size: 80),
              const SizedBox(height: 24),
              Text(
                businessName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tu cuenta está siendo activada.\nTe avisaremos por WhatsApp cuando esté lista.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  await _supabase.auth.signOut();
                  if (mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
