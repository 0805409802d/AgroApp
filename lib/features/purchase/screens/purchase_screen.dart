// purchase_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/business_provider.dart';
import '../../../core/services/advance_provider.dart'; // 🆕 FASE 1
import '../../../core/utils/whatsapp_helper.dart';
import '../../../shared/models/farmer_model.dart';
import '../../../shared/models/purchase_model.dart';
import '../../../shared/models/advance_model.dart'; // 🆕 FASE 1
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/models/offline_models.dart';

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
  String _discountMode = 'porcentaje';
  bool _saving = false;

  // 🆕 FASE 1 — Adelantos automáticos
  FarmerModel? _selectedFarmer;
  List<AdvanceModel> _pendingAdvances = [];
  List<String> _selectedAdvanceIds = [];
  List<double> _deductionAmounts = [];
  double _autoAdvanceDeducted = 0;

  // 🆕 Sistema inteligente de descuentos
  List<double> _discountSuggestions = []; // chips sugeridos
  bool _discountAutoFilled = false; // si se autorrellenó

  // 🆕 Errores de validación
  String? _grossWeightError;
  String? _discountValueError;
  String? _advanceError;

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

  // ── Selección de agricultor ───────────────────────────────

  void _onFarmerNameChanged(String value) {
    if (value.length < 2) {
      setState(() => _showSuggestions = false);
      return;
    }
    final filtered = _allFarmers
        .where((f) => f.name.toLowerCase().contains(value.toLowerCase()))
        .take(20)
        .toList();
    setState(() {
      _filteredFarmers = filtered;
      _showSuggestions = filtered.isNotEmpty;
    });
  }

  // 🆕 FASE 1 — Al seleccionar agricultor cargamos sus adelantos y analizamos descuentos
  Future<void> _selectFarmer(FarmerModel farmer) async {
    _farmerNameController.text = farmer.name;
    _whatsappController.text = farmer.whatsappNumber ?? '';
    setState(() {
      _showSuggestions = false;
      _selectedFarmer = farmer;
      _pendingAdvances = [];
      _selectedAdvanceIds = [];
      _deductionAmounts = [];
      _autoAdvanceDeducted = 0;
      _discountSuggestions = [];
      _discountAutoFilled = false;
    });
    final advanceProvider = context.read<AdvanceProvider>();
    await advanceProvider.loadPendingAdvances(farmer.id);
    final advances = advanceProvider.pendingAdvances;

    // 🧠 Análisis de historial de descuentos
    await _analyzeDiscountHistory(farmer.id);

    if (mounted) {
      setState(() {
        _pendingAdvances = advances;
      });
    }
  }

  // 🧠 Analiza el historial de descuentos del agricultor
  Future<void> _analyzeDiscountHistory(String farmerId) async {
    final business = context.read<BusinessProvider>().business;
    if (business == null) return;

    final data = await _supabase
        .from('purchases')
        .select('discount_value, discount_type')
        .eq('business_id', business.id)
        .eq('farmer_id', farmerId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(20);

    if ((data as List).isEmpty) return;

    // Agrupar valores de descuento por frecuencia
    final Map<String, int> freq = {};
    for (final row in data) {
      final val = (row['discount_value'] as num).toDouble();
      final type = row['discount_type'] as String;
      final key = '${val.toStringAsFixed(2)}_$type';
      freq[key] = (freq[key] ?? 0) + 1;
    }

    // Ordenar por frecuencia descendente
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) return;

    // Top valor (el más frecuente)
    final topEntry = sorted.first;
    final topParts = topEntry.key.split('_');
    final topVal = double.parse(topParts[0]);
    final topType = topParts[1];
    final topCount = topEntry.value;

    // Si el tipo coincide con el modo actual y hay 5+ repeticiones → autorellenar
    if (topCount >= 5 && topType == _discountMode) {
      setState(() {
        _discountValueController.text = topVal % 1 == 0
            ? topVal.toInt().toString()
            : topVal.toStringAsFixed(2);
        _discountAutoFilled = true;
      });
      _recalculate();
    }

    // Chips: top 4 valores más frecuentes (del mismo tipo de descuento)
    final suggestions = sorted
        .where((e) {
          final parts = e.key.split('_');
          return parts[1] == _discountMode && double.parse(parts[0]) > 0;
        })
        .take(4)
        .map((e) => double.parse(e.key.split('_')[0]))
        .toList();

    if (suggestions.length >= 2) {
      setState(() => _discountSuggestions = suggestions);
    }
  }

  // 🆕 FASE 1 — Toggle de selección de un adelanto
  void _toggleAdvance(AdvanceModel advance, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedAdvanceIds.add(advance.id);
        // Descontamos todo el saldo restante (o podrías limitar al total a pagar)
        _deductionAmounts.add(advance.remaining);
      } else {
        final idx = _selectedAdvanceIds.indexOf(advance.id);
        if (idx != -1) {
          _selectedAdvanceIds.removeAt(idx);
          _deductionAmounts.removeAt(idx);
        }
      }
      _recalculateAutoAdvance();
    });
  }

  // 🆕 FASE 1 — Suma lo que se va a descontar de los adelantos seleccionados
  void _recalculateAutoAdvance() {
    double total = 0;
    for (final amt in _deductionAmounts) {
      total += amt;
    }
    // No podemos descontar más que el subtotal (el total a pagar sin descuentos)
    if (total > _subtotal) {
      total = _subtotal;
    }
    setState(() {
      _autoAdvanceDeducted = total;
    });
  }

  // ── Cálculo principal (modificado) ─────────────────────────

  void _recalculate() {
    final business = context.read<BusinessProvider>().business;
    if (business == null) return;

    final grossText = _grossWeightController.text.replaceAll(',', '.');
    final discountValText = _discountValueController.text.replaceAll(',', '.');
    final advanceText = _advanceController.text.replaceAll(',', '.');

    setState(() {
      _grossWeightError = (grossText.isNotEmpty && double.tryParse(grossText) == null) 
          ? 'Solo se aceptan números' : null;
      _discountValueError = (discountValText.isNotEmpty && double.tryParse(discountValText) == null) 
          ? 'Solo se aceptan números' : null;
      _advanceError = (advanceText.isNotEmpty && double.tryParse(advanceText) == null) 
          ? 'Solo se aceptan números' : null;
    });

    final gross = double.tryParse(grossText) ?? 0;
    final discountVal = double.tryParse(discountValText) ?? 0;

    double net;
    if (_discountMode == 'porcentaje') {
      net = gross - (gross * discountVal / 100);
    } else {
      net = gross - discountVal;
    }
    if (net < 0) net = 0;

    final sub = net * business.currentPrice;

    // 🆕 FASE 1 — El avance a descontar es automático si hay adelantos, si no, manual
    double advanceToDeduct;
    if (_pendingAdvances.isNotEmpty) {
      // Se usa el descuento automático (ya calculado en _recalculateAutoAdvance)
      advanceToDeduct = _autoAdvanceDeducted;
    } else {
      // Se usa el campo manual
      advanceToDeduct =
          double.tryParse(_advanceController.text.replaceAll(',', '.')) ?? 0;
    }

    final total = sub - advanceToDeduct;

    setState(() {
      _netWeight = net;
      _subtotal = sub;
      _totalPaid = total < 0 ? 0 : total;
      // Actualizamos también el límite para no descontar más del subtotal
      if (_pendingAdvances.isNotEmpty) {
        _recalculateAutoAdvance();
      }
    });
  }

  // ── Guardar compra ─────────────────────────────────────────

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
      bool isOnline = !(await Connectivity().checkConnectivity()).contains(ConnectivityResult.none);
      
      String? directoryId;
      if (isOnline) {
        final dirData = await _supabase
            .from('folders')
            .select('id')
            .eq('business_id', business.id)
            .eq('name', 'Directorio de Clientes')
            .maybeSingle();
        if (dirData != null) directoryId = dirData['id'];
      }

      // Guardar o actualizar agricultor
      String? farmerId;
      if (_selectedFarmer != null) {
        final wa = _whatsappController.text.trim();
        final existingWa = _selectedFarmer!.whatsappNumber ?? '';
        final isNewContact = wa.isNotEmpty && existingWa.isNotEmpty && wa != existingWa;

        if (isNewContact) {
          farmerId = const Uuid().v4();
          final farmerData = {
            'id': farmerId,
            'business_id': business.id,
            'folder_id': directoryId,
            'name': farmerName,
            'whatsapp_number': wa,
          };
          
          if (isOnline) {
            await _supabase.from('farmers').insert(farmerData);
          } else {
            await LocalDbService.enqueueMutation(OfflineMutation()
              ..mutationId = const Uuid().v4()
              ..collectionName = 'farmers'
              ..action = 'insert'
              ..payload = jsonEncode(farmerData)
              ..createdAt = DateTime.now());
          }
        } else {
          farmerId = _selectedFarmer!.id;
          if (wa.isNotEmpty && existingWa != wa) {
            final updateData = {'id': farmerId, 'whatsapp_number': wa};
            if (isOnline) {
              await _supabase.from('farmers').update({'whatsapp_number': wa}).eq('id', farmerId);
            } else {
              await LocalDbService.enqueueMutation(OfflineMutation()
                ..mutationId = const Uuid().v4()
                ..collectionName = 'farmers'
                ..action = 'update'
                ..payload = jsonEncode(updateData)
                ..createdAt = DateTime.now());
            }
          }
        }
      } else {
        farmerId = const Uuid().v4();
        final newFarmerData = {
          'id': farmerId,
          'business_id': business.id,
          'folder_id': directoryId,
          'name': farmerName,
          'whatsapp_number': _whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim(),
        };
        if (isOnline) {
          await _supabase.from('farmers').insert(newFarmerData);
        } else {
          await LocalDbService.enqueueMutation(OfflineMutation()
            ..mutationId = const Uuid().v4()
            ..collectionName = 'farmers'
            ..action = 'insert'
            ..payload = jsonEncode(newFarmerData)
            ..createdAt = DateTime.now());
            
          await LocalDbService.cacheFarmers([LocalFarmer()
             ..supabaseId = farmerId
             ..businessId = business.id
             ..name = farmerName
             ..whatsappNumber = newFarmerData['whatsapp_number'] ?? '']);
        }
      }

      final discountVal = double.tryParse(
              _discountValueController.text.replaceAll(',', '.')) ?? 0;

      // 🆕 FASE 1 — Determinamos el monto final de adelanto a descontar
      double finalAdvance;
      List<String>? advanceIds;
      List<double>? deductionAmounts;

      if (_pendingAdvances.isNotEmpty && _selectedAdvanceIds.isNotEmpty) {
        // Usar los adelantos automáticos
        finalAdvance = _autoAdvanceDeducted;
        advanceIds = _selectedAdvanceIds;
        deductionAmounts = _deductionAmounts;
      } else {
        // Usar el campo manual (o 0)
        finalAdvance =
            double.tryParse(_advanceController.text.replaceAll(',', '.')) ?? 0;
        advanceIds = null;
        deductionAmounts = null;
      }

      final rpcParams = {
        'p_business_id': business.id,
        'p_farmer_id': farmerId,
        'p_farmer_name': farmerName,
        'p_gross_weight': gross,
        'p_discount_type': _discountMode,
        'p_discount_value': discountVal,
        'p_net_weight': _netWeight,
        'p_weight_unit': business.weightUnit,
        'p_price_per_unit': business.currentPrice,
        'p_subtotal': _subtotal,
        'p_advance_deducted': finalAdvance,
        'p_total_paid': _totalPaid,
        'p_farmer_whatsapp': _whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim(),
        'p_advance_ids': advanceIds,
        'p_deduction_amounts': deductionAmounts,
      };

      if (isOnline) {
        await _supabase.rpc('process_purchase_with_advance', params: rpcParams);

        PurchaseModel? savedPurchase;
        if (sendWhatsApp) {
          final recent = await _supabase
              .from('purchases')
              .select()
              .eq('business_id', business.id)
              .eq('farmer_id', farmerId!)
              .order('created_at', ascending: false)
              .limit(1)
              .single();
          savedPurchase = PurchaseModel.fromMap(recent);

          final wa = _whatsappController.text.trim();
          if (wa.isNotEmpty) {
            final message = WhatsAppHelper.buildReceiptMessage(business: business, purchase: savedPurchase);
            await WhatsAppHelper.sendReceipt(phoneNumber: wa, message: message);
            await _supabase.from('purchases').update({'whatsapp_sent': true}).eq('id', savedPurchase.id);
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compra guardada. No hay WhatsApp.')));
          }
        }
      } else {
        await LocalDbService.enqueueMutation(OfflineMutation()
          ..mutationId = const Uuid().v4()
          ..collectionName = 'process_purchase_with_advance'
          ..action = 'rpc'
          ..payload = jsonEncode(rpcParams)
          ..createdAt = DateTime.now());
          
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Modo Offline: Compra guardada en memoria. Se sincronizará al tener internet.'),
              backgroundColor: Colors.orange,
            ),
          );
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

  // ── Secciones (builders) ────────────────────────────────────

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
          if (_showSuggestions)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: SingleChildScrollView(
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
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              errorText: _grossWeightError,
            ),
          ),
          const SizedBox(height: 16),
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
              errorText: _discountValueError,
            ),
          ),
          if (_discountAutoFilled)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Descuento habitual aplicado automáticamente',
                    style: TextStyle(color: Colors.amber.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          if (!_discountAutoFilled && _discountSuggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                children: _discountSuggestions.map((val) {
                  final textVal = val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(2);
                  return ActionChip(
                    label: Text('-$textVal ${_discountMode == 'porcentaje' ? '%' : unit}'),
                    backgroundColor: const Color(0xFFE8F5E9),
                    labelStyle: const TextStyle(color: Color(0xFF1B5E20), fontSize: 12),
                    onPressed: () {
                      setState(() {
                        _discountValueController.text = textVal;
                      });
                      _recalculate();
                    },
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 12),
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

  // 🆕 FASE 1 — Sección de adelantos adaptada
  Widget _buildAdvanceSection() {
    return _sectionCard(
      title: 'Adelantos',
      icon: Icons.payments_outlined,
      child: _pendingAdvances.isNotEmpty ? _buildAutoAdvances() : _buildManualAdvance(),
    );
  }

  // 🆕 FASE 1 — Widget con checkboxes de adelantos pendientes
  Widget _buildAutoAdvances() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⚡ ${_selectedFarmer?.name ?? "El agricultor"} tiene ${_pendingAdvances.length} adelanto(s) pendiente(s). Selecciona los que deseas descontar hoy.',
          style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ..._pendingAdvances.map((adv) {
          final isSelected = _selectedAdvanceIds.contains(adv.id);
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '\$${adv.remaining.toStringAsFixed(2)} — ${adv.createdAt.toLocal().toString().substring(0, 10)}',
            ),
            subtitle: adv.notes != null && adv.notes!.isNotEmpty
                ? Text(adv.notes!, style: const TextStyle(fontSize: 12))
                : null,
            value: isSelected,
            onChanged: (val) => _toggleAdvance(adv, val),
            controlAffinity: ListTileControlAffinity.leading,
          );
        }),
        const Divider(),
        Text(
          'Total a descontar: \$${_autoAdvanceDeducted.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Manual original (sin cambios)
  Widget _buildManualAdvance() {
    return TextField(
      controller: _advanceController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _fieldDecoration(
        'Descontar adelanto (\$)',
        hint: '0.00 — dejar vacío si no hay',
        errorText: _advanceError,
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
              (_advanceController.text != '0') &&
              _pendingAdvances.isEmpty)
            Text(
              'Subtotal \$${_subtotal.toStringAsFixed(2)} — Adelanto \$${(double.tryParse(_advanceController.text) ?? 0).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          if (_pendingAdvances.isNotEmpty && _autoAdvanceDeducted > 0)
            Text(
              'Subtotal \$${_subtotal.toStringAsFixed(2)} — Adelanto autom. \$${_autoAdvanceDeducted.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
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
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
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

  // ── Helpers de UI (sin cambios) ─────────────────────────────

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

  InputDecoration _fieldDecoration(String label, {String? hint, String? errorText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
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
