import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/services/business_provider.dart';
import '../../../shared/models/purchase_model.dart';
import 'package:intl/intl.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final _supabase = Supabase.instance.client;
  List<PurchaseModel> _archivedPurchases = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadArchived();
  }

  Future<void> _loadArchived() async {
    final businessId = context.read<BusinessProvider>().business?.id;
    if (businessId == null) return;

    final data = await _supabase
        .from('purchases')
        .select()
        .eq('business_id', businessId)
        .not('archived_at', 'is', null)
        .order('created_at', ascending: false);

    setState(() {
      _archivedPurchases = (data as List).map((e) => PurchaseModel.fromMap(e)).toList();
      _loading = false;
    });
  }

  Future<void> _archiveMonth() async {
    final businessId = context.read<BusinessProvider>().business?.id;
    if (businessId == null) return;

    final now = DateTime.now();
    // Archivar todo lo anterior a este mes
    final firstDayOfMonth = DateTime(now.year, now.month, 1).toUtc().toIso8601String();

    await _supabase.rpc('archive_purchases_before', params: {
      'p_business_id': businessId,
      'p_before_date': firstDayOfMonth,
    });

    _loadArchived();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mes anterior archivado correctamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivo de Compras'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _archivedPurchases.isEmpty
              ? const Center(child: Text('No hay compras archivadas.'))
              : ListView.builder(
                  itemCount: _archivedPurchases.length,
                  itemBuilder: (context, index) {
                    final p = _archivedPurchases[index];
                    final date = DateFormat('dd/MM/yyyy').format(p.createdAt);
                    return ListTile(
                      leading: const Icon(Icons.archive),
                      title: Text('${p.farmerName} - $date'),
                      subtitle: Text('Peso: ${p.netWeight} | Total: \$${p.totalPaid}'),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _archiveMonth,
        icon: const Icon(Icons.archive),
        label: const Text('Archivar meses pasados'),
      ),
    );
  }
}
