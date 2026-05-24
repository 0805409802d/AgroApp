import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/services/business_provider.dart';
import '../../../core/services/cash_provider.dart';
import '../../../shared/models/cash_session_model.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  final _openingBalanceController = TextEditingController();
  final _closingBalanceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final businessId = context.read<BusinessProvider>().business?.id;
    if (businessId != null) {
      context.read<CashProvider>().loadTodaySession(businessId);
    }
  }

  @override
  void dispose() {
    _openingBalanceController.dispose();
    _closingBalanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openCash() async {
    final business = context.read<BusinessProvider>().business;
    if (business == null) return; // null-safe: no debería ocurrir
    final amount = double.tryParse(_openingBalanceController.text.replaceAll(',', '.'));
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un saldo inicial válido')),
      );
      return;
    }
    setState(() => _saving = true);
    await context.read<CashProvider>().openCash(
          businessId: business.id,
          openingBalance: amount,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
    setState(() => _saving = false);
  }

  Future<void> _closeCash() async {
    final session = context.read<CashProvider>().currentSession!;
    final closing = double.tryParse(_closingBalanceController.text);
    if (closing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el saldo final real')),
      );
      return;
    }
    setState(() => _saving = true);
    await context.read<CashProvider>().closeCash(
          sessionId: session.id,
          closingBalance: closing,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
    setState(() => _saving = false);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cashProvider = context.watch<CashProvider>();
    final session = cashProvider.currentSession;
    final loading = cashProvider.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja del Día'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : session == null
              ? _buildOpenForm()
              : _buildSessionDetails(cashProvider, session),
    );
  }

  Widget _buildOpenForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.account_balance_wallet, size: 64, color: Color(0xFF2E7D32)),
          const SizedBox(height: 16),
          const Text(
            'Abrir Caja Hoy',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _openingBalanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Efectivo inicial (\$)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notas (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _openCash,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Abrir Caja', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDetails(CashProvider cashProvider, CashSessionModel session) {
    final expected = session.expectedBalance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen de caja
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildRow('Saldo inicial', '\$${session.openingBalance.toStringAsFixed(2)}'),
                  _buildRow('Compras (-)', '\$${session.totalPurchases.toStringAsFixed(2)}'),
                  _buildRow('Adelantos dados (-)', '\$${session.totalAdvancesGiven.toStringAsFixed(2)}'),
                  _buildRow('Adelantos descontados (+)', '\$${session.totalAdvancesDeducted.toStringAsFixed(2)}'),
                  const Divider(),
                  _buildRow('Saldo esperado', '\$${expected.toStringAsFixed(2)}', bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Formulario de cierre
          TextField(
            controller: _closingBalanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Saldo real (\$)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notas (opcional)',
              hintText: session.notes ?? '',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _closeCash,
              icon: const Icon(Icons.lock),
              label: const Text('Cerrar Caja', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Lista de movimientos recientes
          if (cashProvider.movements.isNotEmpty) ...[
            const Text('Movimientos del día', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cashProvider.movements.length,
              itemBuilder: (context, index) {
                final mov = cashProvider.movements[index];
                final isExpense = mov.type == 'purchase' || mov.type == 'advance';
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isExpense ? Colors.red : Colors.green,
                  ),
                  title: Text(mov.description ?? mov.type),
                  trailing: Text(
                    '\$${mov.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isExpense ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}