// business_model.dart
class BusinessModel {
  final String id;
  final String userId;
  final String businessName;
  final String? ownerName;
  final String? whatsappNumber;
  final String productType;
  final String weightUnit;
  final String discountType;
  final double currentPrice;
  final bool isActive;
  final DateTime? subscriptionExpiresAt;

  BusinessModel({
    required this.id,
    required this.userId,
    required this.businessName,
    this.ownerName,
    this.whatsappNumber,
    required this.productType,
    required this.weightUnit,
    required this.discountType,
    required this.currentPrice,
    required this.isActive,
    this.subscriptionExpiresAt,
  });

  factory BusinessModel.fromMap(Map<String, dynamic> map) {
    return BusinessModel(
      id: map['id'],
      userId: map['user_id'],
      businessName: map['business_name'],
      ownerName: map['owner_name'],
      whatsappNumber: map['whatsapp_number'],
      productType: map['product_type'],
      weightUnit: map['weight_unit'],
      discountType: map['discount_type'],
      currentPrice: (map['current_price'] as num).toDouble(),
      isActive: map['is_active'],
      subscriptionExpiresAt: map['subscription_expires_at'] != null
          ? DateTime.parse(map['subscription_expires_at'])
          : null,
    );
  }
}