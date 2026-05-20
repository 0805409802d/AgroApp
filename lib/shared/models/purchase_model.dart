// purchase_model.dart
class PurchaseModel {
  final String id;
  final String businessId;
  final String? farmerId;
  final String farmerName;
  final String? farmerWhatsapp;
  final double grossWeight;
  final String discountType;
  final double discountValue;
  final double netWeight;
  final String weightUnit;
  final double pricePerUnit;
  final double subtotal;
  final double advanceDeducted;
  final double totalPaid;
  final String status;
  final bool whatsappSent;
  final DateTime createdAt;

  PurchaseModel({
    required this.id,
    required this.businessId,
    this.farmerId,
    required this.farmerName,
    this.farmerWhatsapp,
    required this.grossWeight,
    required this.discountType,
    required this.discountValue,
    required this.netWeight,
    required this.weightUnit,
    required this.pricePerUnit,
    required this.subtotal,
    required this.advanceDeducted,
    required this.totalPaid,
    required this.status,
    required this.whatsappSent,
    required this.createdAt,
  });

  factory PurchaseModel.fromMap(Map<String, dynamic> map) {
    return PurchaseModel(
      id: map['id'],
      businessId: map['business_id'],
      farmerId: map['farmer_id'],
      farmerName: map['farmer_name'],
      farmerWhatsapp: map['farmer_whatsapp'],
      grossWeight: (map['gross_weight'] as num).toDouble(),
      discountType: map['discount_type'],
      discountValue: (map['discount_value'] as num).toDouble(),
      netWeight: (map['net_weight'] as num).toDouble(),
      weightUnit: map['weight_unit'],
      pricePerUnit: (map['price_per_unit'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      advanceDeducted: (map['advance_deducted'] as num).toDouble(),
      totalPaid: (map['total_paid'] as num).toDouble(),
      status: map['status'],
      whatsappSent: map['whatsapp_sent'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}