import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../../core/services/business_provider.dart';
import '../../../shared/models/farmer_model.dart';
import '../../../shared/models/purchase_model.dart';

class ContactProfileScreen extends StatefulWidget {
  final String farmerId;

  const ContactProfileScreen({super.key, required this.farmerId});

  @override
  State<ContactProfileScreen> createState() => _ContactProfileScreenState();
}

class _ContactProfileScreenState extends State<ContactProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  FarmerModel? _contact;
  List<PurchaseModel> _allPurchases = [];
  List<PurchaseModel> _filteredPurchases = [];

  // Filtro
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final businessId = context.read<BusinessProvider>().business?.id;
      if (businessId == null) return;

      // Cargar contacto
      final contactData = await _supabase
          .from('farmers')
          .select()
          .eq('id', widget.farmerId)
          .single();
      _contact = FarmerModel.fromMap(contactData);

      // Cargar historial de compras (ventas del cliente)
      final purchasesData = await _supabase
          .from('purchases')
          .select()
          .eq('farmer_id', widget.farmerId)
          .order('created_at', ascending: false);
      
      _allPurchases = (purchasesData as List).map((e) => PurchaseModel.fromMap(e)).toList();
      _applyFilter();

    } catch (e) {
      debugPrint('Error loading contact profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredPurchases = _allPurchases.where((p) {
        final date = p.createdAt.toLocal();
        return date.month == _selectedMonth && date.year == _selectedYear;
      }).toList();
    });
  }

  Future<void> _generateExcel() async {
    if (_filteredPurchases.isEmpty) return;

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Historial'];
    excel.setDefaultSheet('Historial');

    // Encabezados
    sheetObject.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Peso Neto'),
      TextCellValue('Unidad'),
      TextCellValue('Precio Unitario'),
      TextCellValue('Subtotal'),
      TextCellValue('Total Pagado'),
      TextCellValue('Estado'),
    ]);

    double totalPaid = 0;
    double totalWeight = 0;

    for (var p in _filteredPurchases) {
      final date = DateFormat('dd/MM/yyyy HH:mm').format(p.createdAt.toLocal());
      sheetObject.appendRow([
        TextCellValue(date),
        DoubleCellValue(p.netWeight),
        TextCellValue(p.weightUnit),
        DoubleCellValue(p.pricePerUnit),
        DoubleCellValue(p.subtotal),
        DoubleCellValue(p.totalPaid),
        TextCellValue(p.status),
      ]);

      if (p.status == 'active') {
        totalPaid += p.totalPaid;
        totalWeight += p.netWeight;
      }
    }

    // Fila de totales
    sheetObject.appendRow([
      TextCellValue('TOTAL'),
      DoubleCellValue(totalWeight),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalPaid),
      TextCellValue(''),
    ]);

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final dir = await getApplicationDocumentsDirectory();
      final monthName = DateFormat('MMMM_yyyy').format(DateTime(_selectedYear, _selectedMonth));
      final filePath = '${dir.path}/Historial_${_contact!.name.replaceAll(' ', '_')}_$monthName.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      await Share.shareXFiles([XFile(filePath)], text: 'Historial de ${_contact!.name} - $monthName');
    }
  }

  Future<void> _sendWhatsApp() async {
    if (_filteredPurchases.isEmpty) return;
    final phone = _contact?.whatsappNumber;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El contacto no tiene un número de teléfono guardado.')));
      return;
    }

    final monthName = DateFormat('MMMM yyyy', 'es').format(DateTime(_selectedYear, _selectedMonth));
    
    double totalPaid = 0;
    double totalWeight = 0;
    for (var p in _filteredPurchases) {
      if (p.status == 'active') {
        totalPaid += p.totalPaid;
        totalWeight += p.netWeight;
      }
    }

    final msg = '''
Hola ${_contact!.name},
Este es el resumen de transacciones de $monthName:

Total entregado: ${totalWeight.toStringAsFixed(2)}
Total pagado: \$${totalPaid.toStringAsFixed(2)}

¡Gracias por trabajar con nosotros!
''';

    final uri = Uri.parse('https://wa.me/593${phone.startsWith('0') ? phone.substring(1) : phone}?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil no encontrado')),
        body: const Center(child: Text('El contacto no existe.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(_contact!.name),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Info del Contacto
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.person, size: 40, color: Color(0xFF1B5E20)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_contact!.name} ${_contact!.lastName ?? ''}'.trim(),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          if (_contact!.whatsappNumber != null)
                            Text('Tel: ${_contact!.whatsappNumber}', style: const TextStyle(color: Colors.grey)),
                          if (_contact!.email != null)
                            Text('Correo: ${_contact!.email}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_contact!.description != null) ...[
                  const SizedBox(height: 16),
                  Text(_contact!.description!, style: const TextStyle(fontStyle: FontStyle.italic)),
                ]
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // Filtro y Botones de Exportación
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filtrar Mes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        DropdownButton<int>(
                          value: _selectedMonth,
                          items: List.generate(12, (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text(DateFormat('MMMM', 'es').format(DateTime(2000, index + 1))),
                          )),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedMonth = val);
                              _applyFilter();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _selectedYear,
                          items: List.generate(10, (index) => DropdownMenuItem(
                            value: DateTime.now().year - 5 + index,
                            child: Text('${DateTime.now().year - 5 + index}'),
                          )),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedYear = val);
                              _applyFilter();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _filteredPurchases.isEmpty ? null : _generateExcel,
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Generar Excel'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _filteredPurchases.isEmpty ? null : _sendWhatsApp,
                        icon: const Icon(Icons.chat),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Historial de compras
          Expanded(
            child: _filteredPurchases.isEmpty
                ? const Center(child: Text('No hay registros en este mes', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredPurchases.length,
                    itemBuilder: (ctx, index) {
                      final p = _filteredPurchases[index];
                      final date = DateFormat('dd MMM yyyy, HH:mm', 'es').format(p.createdAt.toLocal());
                      final isCancelled = p.status == 'cancelled';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            '\$${p.totalPaid.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isCancelled ? Colors.red : Colors.black,
                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text('$date\n${p.netWeight.toStringAsFixed(2)} ${p.weightUnit}'),
                          isThreeLine: true,
                          trailing: isCancelled ? const Chip(label: Text('Anulada'), backgroundColor: Colors.redAccent) : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
